#!/bin/perl

# TODO: don't broadcast password sent by player on create

use Net::WebSocket::Server;
require "/usr/local/lib/bclib.pl";
require "/sites/YAMC/yamc-lib.pl";
require "/sites/YAMC/game-commands.pl";

# TODO: is this an improper use of globopts?
$globopts{websocket} = 1;

my($ws)=Net::WebSocket::Server->new(listen=>8000,on_connect => \&connection);
$ws->start;

# TODO: when someone connects, broadcast to all connected
sub connection {
  my($serv, $conn) = @_;
  $conn->on(utf8 => \&message);
}

# this happens when we get a message
sub message {
  my($conn, $msg) = @_;

  # processes the msg
  process_msg($msg);

  # parse the message and broadcast it
#  my(%hash) = parse_form($msg);
#  broadcast("$hash{user}: $hash{command}");
}


# broadcast to all connections w/ timestamp
sub broadcast {
  my($msg) = @_;

  my($time) = stardate();
  $msg = "[$time] $msg";

  for $i ($ws->connections) {$i->send_utf8($msg);}
}

# TODO: client should warn if disconnected

sub process_msg {
  my($msg) = @_;
  debug("PROCESS_MSG($msg)");

  # sanitize
  unless ($msg=~/^[a-z0-9_ &=]*$/i) {
    tell_user("Input *$msg* contained invalid characters, ignoring");
    return;
  }

  my(%hash) = parse_form($msg);
  my($fullcmd) = $hash{cmd};
  our($user) = $hash{user};

  unless ($user) {
    tell_user("Please enter a username");
    return;
  }

  # parse the command, so that "a b c" becomes "command_a(b,c)"
  my(@cmd) = split(/\s+/, $fullcmd);
  $cmd = shift(@cmd);

  broadcast("(from $user): $fullcmd");

  # allow command aliasing
  if ($command_aliases{$cmd}) {$cmd = $command_aliases{$cmd};}

  my($args) = join(", ",@cmd);
  my($eval) = "command_$cmd($args)";

  # this is what we plan to evaluate
#  tell_user("Eval: $eval");

  # check user info and store in global hash
  our(%user) = get_user_info($user);

  # these commands can be called even if no user is defined
  if ($no_user_required{$cmd}) {
    eval($eval);
    return;
  }

  if ($user{null}) {
    tell_user("User $user does not exist: 'create $user password' to create");
    return;
  }

  tell_user("Plan to call: $eval");
  eval($eval);
  tell_user("Eval returns $@");
}

sub get_user_info {

  my($user) = @_;
  my(%user);

  my(@user) = sqlite3hashlist("SELECT * FROM users WHERE username='$user'", $dbfile);

  if ($#user == -1) {$user{null} = 1; return %user;}

  for $i (@user) {$user{$i->{variable}} = $i->{value};}

  return %user;
}


  
