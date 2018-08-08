package com.redhat.consulting.odie.servlet;

import com.codahale.metrics.health.HealthCheckRegistry;
import com.codahale.metrics.servlets.HealthCheckServlet;
import com.redhat.consulting.odie.checks.AMQHealthCheck;
import com.redhat.consulting.odie.checks.DBHealthCheck;

import javax.ejb.DependsOn;
import javax.inject.Inject;
import javax.servlet.annotation.WebListener;

@WebListener
@DependsOn("AMQHealthCheck")
public class ODIEHealthCheckServletContextListener extends HealthCheckServlet.ContextListener {

  public final static HealthCheckRegistry HEALTH_CHECK_REGISTRY = new HealthCheckRegistry();

  @Inject
  protected AMQHealthCheck amqHealthCheck;


  public ODIEHealthCheckServletContextListener() {
    //HEALTH_CHECK_REGISTRY.register("amq-broker", amqHealthCheck);
    HEALTH_CHECK_REGISTRY.register("postgres-db", new DBHealthCheck());
  }

  @Override
  protected HealthCheckRegistry getHealthCheckRegistry() {
    return HEALTH_CHECK_REGISTRY;
  }

}
