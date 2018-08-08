toodie_func() {
  if [ -n "$1" ]; then
    cd "/opt/odie/$1";
   else
    cd /opt/odie;
   fi
}

view_list_select() {
  echo "Enter the number of the file you want to view:"

  PS3="View log: "
  touch "$QUIT"

  select FILENAME in $(ls -1t /tmp | grep odie);
  do
    less /tmp/$FILENAME
    break
  done
}

alias tailodie='tail -f "/tmp/$(ls -1tr /tmp | grep odie | tail -1)"'
alias viewodie=view_list_select
alias toodie=toodie_func

