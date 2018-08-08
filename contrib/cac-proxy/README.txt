# Containerized PIV/CAC Authentication Proxy for OpenShift

## Overview
This project is to provide a streamlined process for implementing a PIV/CAC authenticating proxy for OpenShift Origin and Enterprise (OCP). The containers provided can be either CentOS or RHEL7 based. The advanced configuration can be performed without creating a new project or forking this one. The process is easy to understand and can be completed in a few steps by administrators.

## References
This was created from the documentation provided by OpenShift for versions [3.4](https://docs.openshift.com/container-platform/3.4/install_config/configuring_authentication.html#RequestHeaderIdentityProvider), [3.5](https://docs.openshift.com/container-platform/3.5/admin_solutions/authentication.html#request-header-auth), and [3.6](https://docs.openshift.com/container-platform/3.6/admin_solutions/authentication.html#request-header-auth).

## Requirements
* OpenShift Origin/Enterprise 3.4+
* SSH access to **at least one** Master node
  * Sudo or root access on that node
* Certificate Material for Authentication Endpoint
  * Private Key (ex: hostname.key)
  * Public Cert (ex: hostname.crt)
* Certificate Authority chain for verifying the client's smart card token (PIV/CAC)
  * Generally issued by the identification granting agency
  * Must contain **all** of the required authorities concatenated into one file
  * Must contain the **entire** trust chain as well; all the way to the root

## Publicly Available PKI Materials
The reason that links to government infrastructure are provided here is because these pages can be difficult to find. It is important to use _correct_ and _properly trusted_ certificate material to ensure the security and integrity of any authentication performed to OpenShift with this method.
* [Health and Human Services PKI Downloads](https://ocio.nih.gov/Smartcard/Pages/PKI_chain.aspx)
* [Department of Defense PKI Downloads](https://iase.disa.mil/pki-pke/Pages/tools.aspx)
* [Department of Treasury PKI Downloads](http://pki.treas.gov/crl_certs.htm)

## Variables
Variables in this document are denoted with `<variable>`. These are items that the user/configurer should be careful to note as they may not have defaults. There are two variables that are required to complete the configuration and have _no_ default value.
* **`<public pivproxy url>`** - the publicly accessible URL for the PIV proxy created in this guide. The master console _will redirect_ traffic to this URL when a login is required. This URL must be accessible and routable by clients needing to authenticate. Typically this would follow the application name, namespace, and cloud DNS base pattern. You could create a custom route for it if your hosting environment can support that.
* **`<public master url>`** - the public URL used by clients to reach the master console. The PIV proxy will need to redirect traffic from itself to this URL to complete the authentication process.

_Be sure to replace any instance of these variables in the below documentation with your own site-specific values._

## Instructions

These instructions are written using examples. You do not need to use the same examples but you can modify them as needed. The default project namespace is named `pivproxy` but any other namespace can be used as long as the appropriate changes are made.

### Identify the Target Namespace
```bash
[]$ oc projects
You have access to the following projects and can switch between them with 'oc project <projectname>':

    default
    kube-public
    kube-system
    myproject - My Project
    openshift
    openshift-infra
  * pivproxy

Using project "default" on server "..."
[]$ oc project pivproxy
Now using project "pivproxy" on server "..."
```

If you need to create the project:
```bash
[]$ oc new-project pivproxy
```

### Create the PIV Proxy Client PKI Secret
In order to create a trusted communication channel between the server and the client there needs to be a set of PKI for the client (in this case the PIV proxy) to contact the target master. The master must also trust this communication and can be configured to allow only communication from this source. This prevents some third party from setting up their own authentication server and, through various forms of manipulation, using it as a fake source of authentication information.

These commands must be performed on any **ONE** master node as root (`sudo -i`).
```bash
[]$ export PIV_SECRET_BASEDIR=/etc/origin/proxy
[]$ mkdir -p $PIV_SECRET_BASEDIR
[]$ oc adm ca create-signer-cert \
    --cert=$PIV_SECRET_BASEDIR/proxyca.crt \
    --key=$PIV_SECRET_BASEDIR/proxyca.key \
    --name='openshift-proxy-signer@`date +%s`' \
    --serial=$PIV_SECRET_BASEDIR/proxyca.serial.txt
[]$ oc adm create-api-client-config \
    --certificate-authority=$PIV_SECRET_BASEDIR/proxyca.crt \
    --client-dir=$PIV_SECRET_BASEDIR \
    --signer-cert=$PIV_SECRET_BASEDIR/proxyca.crt \
    --signer-key=$PIV_SECRET_BASEDIR/proxyca.key \
    --signer-serial=$PIV_SECRET_BASEDIR/proxyca.serial.txt \
    --user='system:proxy'
[]$ cat $PIV_SECRET_BASEDIR/system\:proxy.crt \
      $PIV_SECRET_BASEDIR/system\:proxy.key \
      > $PIV_SECRET_BASEDIR/piv_proxy.pem
```
_Note: these commands can actually be executed **anywhere** but executing them on the first master is considerably easier when it has the `oc` client installed already. In that case you can adjust the paths so that they are in a temporary or local directory like `./proxy`._

Then copy the files from the `/etc/origin/proxy` directory to each other master.
```bash
[]$ scp /etc/origin/proxy master2:/etc/origin/proxy
[]$ scp /etc/origin/proxy master3:/etc/origin/proxy
```
_Note: this is not strictly necessary but keeps the files available in case they need to be reused or client material needs to be regenerated._

Then copy the `piv_proxy.pem` to the node that the following commands will be executed from. These commands can be performed anywhere there is an `oc` client installed or they can be performed right on the master. **Also** copy the master's CA from `/etc/origin/master/ca.crt`.
```bash
[]$ scp master1:/etc/origin/proxy/piv_proxy.pem /local/path/to/piv_proxy.pem
[]$ scp master1:/etc/origin/master/ca.crt /local/path/to/master-ca.crt
[]$ oc secret new ose-pivproxy-client-secrets piv_proxy.pem=/local/path/to/piv_proxy.pem master-ca.crt=/local/path/to/master-ca.crt
```

### Create the Smartcard CA Secret
You will need to copy the issued CA that contains the trust for all of the authorized smart cards to a machine that has the `oc` client installed. Then you will use that material to create the target secret. The trust should be _all_ of the potential certificates that are used to sign the tokens (x509/PIV/CAC) that will be presented by authorized users. These certificates _must_ be concatenated into one file.

```bash
[]$ cat smartcard-issuer-1.crt >> /path/to/smartcard-ca-chain-file.crt
[]$ cat smartcard-issuer-2.crt >> /path/to/smartcard-ca-chain-file.crt
[]$ oc secret new ose-pivproxy-smartcard-ca smartcard-ca.crt=/path/to/smartcard-ca-chain-file.crt
```

If you don't have a chain or you just want to see how this works in a test environment [go here](#i-dont-have-a-client-authoritychaincertificate).

### Apply and Use the Build Configuration Template
There are two different builds that can be used for this deployment. The **default** is for a CentOS container to be built. If you have the supporting infrastructure that you can use (or need to use) a RHEL7 image then you can build that instead by using a different dockerfile when you process the build template.

**For CentOS**
```bash
[]$ oc apply -f ./ose-pivproxy-build-template.yml
[]$ oc process ose-pivproxy-build | oc apply -f -
[]$ oc start-build ose-pivproxy-bc
```

**For RHEL7**
```bash
[]$ oc apply -f ./ose-pivproxy-build-template.yml
[]$ oc process ose-pivproxy-build -p DOCKERFILE=Dockerfile.rhel7 | oc apply -f -
[]$ oc start-build ose-pivproxy-bc
```

These commands can (and should) be run any time the build template is changed to reflect any updates.

### Apply and Use the Application Template
```bash
[]$ oc apply -f ./ose-pivproxy-deployment-template.yml
[]$ oc new-app --template=ose-pivproxy -p P_PIVPROXY_PUBLIC_URL=<public pivproxy url> -p P_MASTER_PUBLIC_URL=<public master url>
[]$ oc rollout latest dc/ose-pivproxy
```

These commands can be run any time the deployment template is changed. You can run `oc delete dc/ose-pivproxy svc/ose-pivproxy route/ose-pivproxy` at any time to clean up the deployment so that it can be removed or recreated. The variable P_MASTER_PUBLIC_URL is used in variable expressions like `https://${P_PIVPROXY_PUBLIC_URL}`. In the event that you need to use a different port for the master URL a colon and port can be appended like `:8443`.

```bash
[]$ oc new-app --template=ose-pivproxy -p P_PIVPROXY_PUBLIC_URL=auth.ocp.com -p P_MASTER_PUBLIC_URL=master.ocp.com:8443
```

The url and port can be changed later at any time.
```bash
[]$ oc set env dc/ose-pivproxy P_MASTER_PUBLIC_URL=new.ocp.com:8443
```

### Use Site-Specific Certificates for HTTPS/TLS
In order to have trusted site-specific certificates you will need to gather two pieces of information for the eventual route to serve the proper TLS connection. The application uses a passthrough route because of the client certificate authorization on the application side. This means that, among other things, the server certificates provided **must** have the proper hostname in **both** the CN **and** the alternative name list. _Failure to have proper TLS certificates will result in a non-working PIV proxy._

There are two pieces of required material:
* The server certificate for the hostname
* The server private key matching the certificate

**If you do not have server certificates** you can create them easily with the `oc` command. (From a master node.)
```bash
[]$ oc adm ca create-server-cert \
    --cert='/etc/origin/proxy/<public pivproxy url>.crt' \
    --key='/etc/origin/proxy/<public pivproxy url>.key' \
    --hostnames=<public pivproxy url>,ose-pivproxy.svc,ose-pivproxy.pivproxy.svc,ose-pivproxy.pivproxy.svc.default.local \
    --signer-cert=/etc/origin/master/ca.crt \
    --signer-key='/etc/origin/master/ca.key' \
    --signer-serial='/etc/origin/master/ca.serial.txt'
```

You can verify that the server certificate is correct by checking the subject alternate name provided.
```bash
[]$ openssl x509 -in /path/to/<public pivproxy url>.crt -noout -text | grep -a2 X509v3
  X509v3 Subject Alternative Name:                                    
    DNS:<public pivproxy url>, DNS:<another expected host name>
```

_If the "DNS:" entries are not present or do not match the expected route the certificates will need to be reissued._

Now you can recreate the secret `ose-pivproxy-certs` and override the secrets that were automatically generated when the server was created. These commands will create a new secret in place of the automatically generated one.
```bash
[]$ oc get secret/ose-pivproxy-certs -o yaml > ose-pivproxy-certs.yml.backup
[]$ oc delete secret/ose-pivproxy-certs
[]$ oc secret new ose-pivproxy-certs tls.key=/path/to/hostname.key tls.crt=/path/to/hostname.crt
```

If authentication proxy pods were already running they should be destroyed to reload the secret.
```bash
[]$ oc delete pods --selector app=ose-pivproxy
```

### Configure Master(s) to use PIV Proxy

The following identitiy provider needs to be added to the OCP master configuration. On each of the master nodes edit `/etc/origin/master/master-config.yaml` and add the following yaml to the `identityProviders` block as shown.

```yaml
identityProviders:
  - name: "ocp_pivproxy"
    login: true
    challenge: false
    mappingMethod: add
    provider:
      apiVersion: v1
      kind: RequestHeaderIdentityProvider
      challengeURL: "https://<public pivproxy url>/challenging-proxy/oauth/authorize?${query}"
      loginURL: "https://<public pivproxy url>/login-proxy/oauth/authorize?${query}"
      clientCA: /etc/origin/proxy/proxyca.crt
      clientCommonNames:
       - <public pivproxy url>
       - system:proxy
      headers:
      - X-Remote-User
```

Once this is added, restart the master. _If there is more than one master then each master must be edited and restarted._

## Customizing the HTTPD Configuration

### Creating the Configuration Override File
The [default httpd configuration](/pivproxy.conf) is set up to provide what can be seen as the _minimum_ viable configuration. In order to implement your own configuration the easiest way is to add a `pivproxy.conf` to do the ConfigMap `ose-pivproxy`. To do this you can either start with the `[default configuration](/pivproxy.conf)` or you can pull the configuration from the running container with `oc rsh <pod> cat /apache/default-pivproxy.conf > pivproxy.conf`.

Once the configuration is saved locally you can edit it. After the file has been edited the it can be added to the ConfigMap.
```bash
[]$ oc delete configmap/ose-pivproxy
[]$ oc create configmap ose-pivproxy --from-file=pivproxy.conf=/path/to/edited/pivproxy.conf
```

If the ConfigMap needs to be updated it can be edited in place or the above steps can be followed and the ConfigMap can be deleted and re-added. If at any time you need to revert to the default configuration the `pivproxy.conf` item can be deleted from the configmap leaving an empty `data: {}` block.

To restart the pods simply kill them all and let the replication controller handle it:
```bash
[]$ oc delete pods --selector app=ose-pivproxy
```

### Changing the User's ID and Display Name
The default configuration is to get the _first_ msUPN from the SAN section of the client's cert, remove anything after the '@' symbol (treating it as an email address) and then use that as both the user's identifier and as the display name.

The relevant parts of this configuration are:
```
RewriteRule ^.* - [E=X_LOWER_USER:${lc:%{SSL:SSL_CLIENT_SAN_OTHER_msUPN_0}},L]
RequestHeader set X-Remote-User "%{X_LOWER_USER}e" env=X_LOWER_USER
RequestHeader edit X-Remote-User "([^@]+)@.*" $1
```

This takes the SSL variable SSL_CLIENT_SAN_OTHER_msUPN_0 and converts it to lower case and then sets the request header `X-Remote-User` to be the lower-cased version of the msUPN. Then everything before the '@' is selected and saved in the edited version of the `X-Remote-User` header.

In the `master-config.yaml` on the master node(s) the configuration instructs OpenShift to use the `X-Remote-User` header as the first source of the user id. (The `headers` variable is used for user ID.)
```yaml
identityProviders:
  - name: "ocp_pivproxy"
    # snip ...
    provider:
      # snip...
      headers:
      - X-Remote-User
```

There are many ways that you can adjust or add to this configuration. One basic way would be to use the CN of the presented certificate as the user's display name. This is useful in situations where the msUPN is only a number as with some configurations. (Where the EDIPI number is used in the msUPN field for example.)

Add the following to your customized `pivproxy.conf` after the last `RequestHeader edit` line. After editing the file you will need to recreate the secret and restart the ose-pivproxy pods.
```
RequestHeader set X-Remote-User-Display-Name "%{SSL_CLIENT_S_DN_CN}e" env=SSL_CLIENT_S_DN_CN
```

The `master-config.yaml` must also be edited to have OpenShift use the information passed in from the `X-Remote-User-Display-Name` header. After the `headers` property a `nameHeaders` property should be added.
```yaml
identityProviders:
  - name: "ocp_pivproxy"
    # snip ...
    provider:
      # snip...
      headers:
      - X-Remote-User
      nameHeaders:
      - X-Remote-User-Display-Name
```

This is just one example of the modifications that can be made to pass in different types of information to OpenShift for both the user's id as well as the display name. More information on the variables available from SSL can be [found in the Apache mod_ssl documentation](https://httpd.apache.org/docs/current/mod/mod_ssl.html) under the "Environment Variables" header.

## Testing and Development

### I Don't Have a Client Authority/Chain/Certificate
In the event that you do not have a smartcard infrastructure or you need a faster way to test you can create your own CA and certificate you can follow these instructions. These are also useful if you do not have a PIV/CAC or do not have the appropriate hardware or support to utilize a smartcard on your hardware.

First you will need to generate the authority (which will be a self-signed authority). Follow the prompts and fill out the values as needed.

```bash
[]$ openssl genrsa -out piv_root_ca.key 2048
[]$ openssl req -x509 -new -nodes -key piv_root_ca.key -sha512 -days 1024 -out piv_root_ca.crt
```

Then you will need to create a signing request. The default configuration for the HTTPD authentication proxy uses the msUPN as the username so you will want to make sure that is set. You can do this with a custom openssl configuration.
```bash
cat > ./client_cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[ v3_req ]
basicConstraints = critical,CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
nsCertType = client,server
subjectAltName = @alt_names

[alt_names]
otherName=msUPN;UTF8:<put user name here>
EOF
```

Once the client certificate configuration has been saved and adjusted as needed the rest of the PKI material can be generated. Follow the prompts as appropriate on each command if needed.
```bash
openssl genrsa -out client_cert.key 2048
openssl req -new -key client_cert.key -sha512 -out client_cert.csr
openssl x509 -req -in client_cert.csr -CA piv_root_ca.crt -CAkey piv_root_ca.key -CAcreateserial -out client_cert.crt -days 1024 -sha512 -extfile client_cert.conf -extensions v3_req
```

You can load the certificate authority (`piv_root_ca.crt`) into the smartcard-ca secret in your pivproxy project in OpenShift.
```bash
[]$ oc delete secret ose-pivproxy-smartcard-ca
[]$ oc secret new ose-pivproxy-smartcard-ca smartcard-ca.crt=piv_root_ca.crt
```

Now the **client** certificate you created (`client_cert.crt`) can be used with your browser to provide x509 authentication without needed a hard token or any of the other PKI/PIV infrastructure.

## Troubleshooting
There is a value, which defaults to `info` that can be set in `dc/ose-pivproxy`. This will allow for changing the Apache log level. You can set it to any of the valid values for Apache but something like `debug` or `trace1` through `trace8` would provide the most detail.

```bash
[]$ oc set env dc/ose-pivproxy PROXY_LOG_LEVEL=debug
```

This will cause the application to redeploy and there will be more information in the logs.

## Common Issues

**The main issue you are going to have is with trust and with hostnames for the serving certificate.**

For the serving certificates modern browsers (IE10+, Chrome, Firefox) all **require** that there be a SAN (Subject Alternate Name) that matches the hostname. The CN alone is _no longer_ sufficient _and_ that advice has been added to the SSL/TLS RFCs. The SAN list is the canonical location for the matching DNS name(s).

For the CAC/PIV trust chain it is imperative that _each_ intermediate trust is added. Many government agencies have rotating intermediate certificates that come in scope as new cards are issued and it is common to _forget_ to add new ones which means that new personnel will not be able to access the site. This also means that an older version of the chain may not authenticate new users. Be aware of this and you will stop a lot of issues before they happen.
