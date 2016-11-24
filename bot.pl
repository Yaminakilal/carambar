#!/usr/bin/perl -w
use strict;
use warnings;

# Module IRC
use POE;
use POE::Component::IRC;

# Vars
my $tps_rep = 10;
my $fich_dev = 'devinettes.txt';
my $fich_hist = 'histoires.txt';
my $bot_owner = 'Skelz0r';

# Identifiants
my $serveur = 'IRC.iiens.net';
my $nick = 'Lhauleux';
my $port = 6667;

my $ircname = 'Aïe ! Carambar ! ~ Skelz0r\'s Bot';
my $username = 'Lhauleux';

my @channels = ('#carambar');

## CONNEXION 
my ($irc) = POE::Component::IRC->spawn();

# Evenements que le bot va gérer
POE::Session->create(
  inline_states => {
    _start     => \&bot_start,
    irc_001    => \&on_connect,
    irc_public => \&on_speak,
    irc_join => \&on_join,
  },
);

sub bot_start {
  $irc->yield(register => "all");
  $irc->yield(
    connect => {
      Nick     => $nick,
      Username => $username, 
      Ircname  => $ircname,
      Server   => $serveur,
      Port     => $port,
    }
  );
}

### FONCTIONS
## Recuperation du nombres de devinettes
my $nbr_devinettes = 0;

open(NBR_LIGNES,"$fich_dev") or die ("Impossible d'ouvrir $fich_dev");
while ( <NBR_LIGNES> ) { $nbr_devinettes++; }
close(NBR_LIGNES);

open(DEVINETTES,$fich_dev) or die ("Impossible d'ouvrir $fich_dev !");
my @devinettes = <DEVINETTES>; 
close(DEVINETTES);

$nbr_devinettes /= 2; # 2 lignes par devinettes

## Recuperation du nombres d'histoires "droles"
my @ind_histoires; # valeur = ligne du debut de la blague
my $l;
my $nbr_histoires = 1; # sert d'indice

open(NBR_LIGNES,"$fich_hist") or die ("Impossible d'ouvrir $fich_hist");

$ind_histoires[0] = 0; # init du tableau

while ( defined ( $l = <NBR_LIGNES> ) )
{
   if ( $l eq "---\n" )
   {
      $ind_histoires[$nbr_histoires] = $.;
      $nbr_histoires++;
   }
}

open(HISTOIRES,$fich_hist) or die ("Impossible d'ouvrir $fich_hist !");
my @histoires = <HISTOIRES>; 
close(HISTOIRES);

# Affichage de l'aide
sub aff_help
{
   my ($kernel,$user) = @_;
   
   $irc->yield(privmsg => $user,"!carambar [H|D] [n] : Affiche une blague carambar ( une histoire pour H ou une devinette pour D ) ( la n-ieme ), avec un décalage de $tps_rep secondes pour la réponse si c'est une devinette.");
   $irc->yield(privmsg => $user,'!topic [H|D] [n] : Met une blague carambar en topic ( même options )');
   $irc->yield(privmsg => $user,'!stats : Affiche quelques statistiques');
}

# Affichage des stats
sub stats
{
	my ($kernel,$chan) = @_;
	
	$irc->yield(privmsg => $chan,"Nombre de devinettes : $nbr_devinettes");
	$irc->yield(privmsg => $chan,"Nombre de blagues : $nbr_histoires");
}

# Selection de la blague
sub sel_blague
{
   my ($type,$n_blague) = @_;
   
   # Ouverture du fichier et recuperation de la blague
   if ( $type eq 'D' )
   {
      return ($devinettes[2*$n_blague],$devinettes[2*$n_blague+1]);
   }
   else
   {
   	my $ind_fin_hist = $n_blague+1;
   	my $fin_hist = $ind_histoires[$ind_fin_hist]-2;
   	
      return @histoires[$ind_histoires[$n_blague]..$fin_hist];
   }
}

# Affichage de la blague
sub aff_blague
{
   my ($kernel,$chan,$type,$n_blague) = @_;
   my $ind_blague = $n_blague+1;

   if ( $type eq 'D' )
   {
      my ($quest,$rep) = sel_blague($type,$n_blague);

      $irc->yield(privmsg => $chan,"[Q$ind_blague] $quest");
      $irc->delay( [ privmsg => $chan,"[R$ind_blague] $rep"], $tps_rep );
   }
   else
   {
      my @hist = sel_blague($type,$n_blague);
      my $timer = 0;
      
      foreach (@hist)
      {
         if ( $timer != 0 )
         {
            $irc->delay( [privmsg => $chan,$_], $timer);
         }
         else
         {
            $irc->yield(privmsg => $chan,"[H$ind_blague] $_");
         }
         $timer += 3;
      }
   }

   return;
}

sub set_topic
{
   my ($kernel,$chan,$type,$n_blague) = @_;
   my $topic;

   if ( $type eq 'D' )
   {
      my ($quest,$rep) = sel_blague($type,$n_blague);
      chomp($quest); chomp($rep); # on supprime les \n

      $topic = "$quest : $rep ";
   }
   else
   {
      my @hist = sel_blague($type,$n_blague);
      foreach ( @hist )
      {
         chomp($_);
         $topic .= $_ . ' ';
      }
   }
    
   $irc->yield(topic => $chan,$topic . '| !carambar && !help | CORN!');;
   return;
}

## GESTION EVENTS

# A la connection
sub on_connect
{
  $irc->yield(join => @channels);
}

# Quand un user parle
sub on_speak
{
	my ($kernel,$user_,$msg) = @_[KERNEL, ARG0, ARG2];
   my @chan = @_[ARG1];

   my $user = ( split(/!/,$user_) )[0];

	# Disjonction des cas suivants ce qui est demande
	if ( substr($msg,0,1) eq '!' )
	{
      # Recuperation de la commande & parametres
      my $commande = ( $msg =~ m/^!([^ ]*)/ )[0]; 
      my @params = grep {!/^\s*$/} split(/\s+/, substr($msg, length("!$commande")));

      # Traitement des paramètres
      # Cas de la valeur numerique, en respect avec la numerotation
      $params[1]-- if ( $params[1] =~ m/^\d+$/ && $params[1] < $nbr_histoires && $params[1] >= 0 );

      # Cas de H
      if ( $params[0] eq 'H' )
      {
         $params[1] = int(rand($nbr_histoires-1)) if ( $params[1] !~ m/^\d+$/ || $params[1] >= $nbr_histoires || $params[1] < 0 );
      }
      # Cas de D
      elsif ( $params[0] eq 'D' )
      {
         $params[1] = int(rand($nbr_devinettes-1)) if ( $params[1] !~ m/^\d+$/ || $params[1] >= $nbr_devinettes || $params[1] < 0);
      }
      # Cas général
      else
      {
         # Selection rand()
         if ( int(rand(2)) )
         {
            $params[0] = 'H';
            $params[1] = int(rand($nbr_histoires-1));
         }
         else
         {
            $params[0] = 'D';
            $params[1] = int(rand($nbr_devinettes-1));
         }
      }

      # Gestion commandes
		aff_help($kernel,$user) if ( $commande eq 'help' );

      set_topic($kernel,$chan[0][0],$params[0],$params[1]) if ( $commande eq 'topic' );

      aff_blague($kernel,$chan[0],$params[0],$params[1]) if ( $commande eq 'carambar' );
      
      stats($kernel,$chan[0][0]) if ( $commande eq 'stats' );

      #$irc->yield(mode => "$chan[0][0] +o $user") if ($commande eq 'test'); 
   }
}

# Quand quelqu'un join
sub on_join
{
   my ($kernel,$user_,$msg) = @_[KERNEL, ARG0, ARG2];
   my @chan = @_[ARG1];

   my $user = ( split(/!/,$user_) )[0];

   $irc->yield(mode => "$chan[0] +o $user") if ( $user eq $bot_owner );
}

# Boucle des events
$poe_kernel->run();
exit 0;
