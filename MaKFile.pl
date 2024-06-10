#! /usr/bin/perl

use strict;
use warnings;
use File::Basename;
use Encode qw(encode decode);
use open ':std', ':encoding(UTF-8)';
use Time::HiRes qw(gettimeofday);
use Term::ReadKey;

my $FRAME = 256;

sub cesar {
    my ($line,$key) = @_;
    my $res = "";
    chomp $line;
    if ($key != -1) {
        foreach my $character (split //, $line){
            $res .= chr((ord($character) + $key) % $FRAME);
        }
        $res .= "\n";
    }
    return $res;
}

sub find_cesar_key {
    my ($login,$line) = @_;
    my $key = -1;
    my $name = "";
    chomp $line;
    while (($key < $FRAME) && ($name ne $login)) {
        $key++;
        $name = "";
        foreach my $character (split //, $line) {
            $name .= chr((ord($character) + $key) % $FRAME);
        }
    }
    unless($name eq $login){
        $key = -1;
    }
    return $key;
}

sub encoding {
    my ($directory,$namefile,$extension,$login) = @_;
    open(my $fileRead,"<",$directory."/".$namefile.".".$extension);
    open(my $fileWrite,">",$directory."/".$namefile."tmp.".$extension);
    # Cesar
    my ($seconds, $microseconds) = gettimeofday;
    my $key = sqrt($microseconds * $seconds) % $FRAME;

    print $fileWrite cesar($login, $key);

    while (my $l = <$fileRead>){
        $l = cesar $l,$key;
        print $fileWrite $l;
    }

    close $fileWrite or die "Impossible de fermer le fichier temporaire en écriture : $!";
    close $fileRead or die "Impossible de fermer le fichier en lecture : $!";

    rename $directory."/".$namefile."tmp.".$extension, $directory."/".$namefile.".".$extension or die "Impossible de renommer le fichier temporaire !";
}

sub decoding {
    my ($directory,$namefile,$extension,$login) = @_;
    open(my $fileRead,"<",$directory."/".$namefile.".".$extension);
    my $line = <$fileRead>;
    if (defined($line)) {
        open(my $fileWrite,">",$directory."/".$namefile."tmp.".$extension);
        # ...
        # Cesar
        my $key = find_cesar_key $login, $line;
        unless($key == -1) {
            while (my $l = <$fileRead>){
                # Cesar
                $l = cesar $l, $key;
                print $fileWrite $l;
            }
        } else {
            print "le fichier ne vous appartient pas\n";
        }
        close $fileWrite or die "Impossible de fermer le fichier temporaire en écriture : $!";
        close $fileRead or die "Impossible de fermer le fichier en lecture : $!";
        unless($key == -1) {
            rename $directory."/".$namefile."tmp.".$extension, $directory."/".$namefile.".".$extension or die "Impossible de renommer le fichier temporaire en $directory : $!";
        }
    } else {
        close $fileRead or die "Impossible de fermer le fichier en lecture : $!";
        print "le fichier est vide\n";
    }
}

sub login {
    my ($account, $pass_word, $check);
    do {
        ($account, $pass_word) = (undef, undef);
        do {
            print "enter mail/nickname : ";
            $account = <STDIN>;
            chomp $account;
        } until (defined($account));
        do {
            print "enter password : ";
            ReadMode('noecho');
            $pass_word = <STDIN>;
            ReadMode('normal');
            chomp $pass_word;
            print "\n";
        } until (defined($pass_word));
        $check = check_log($account, $pass_word);
        unless ($check) {
            print "compte non-trouver\n";
        }
    } until ($check);
    print "Bienvenue $account\n";
    return $account;
}

sub check_log {
    my($account,$pass_word) = @_;
    open(my $handler,"<:encoding(UTF-8)","account.txt");
    my ($l,$res);
    $res = 0;
    while( defined( $l = <$handler> ) && ($res == 0)) {
        my @elmnt = split(/\s+/,$l);
        if ($account eq $elmnt[0] || $account eq $elmnt[1]) {
            if ($pass_word eq $elmnt[2]) {
                $res = 1;
            }
        }
    }
    close($handler) or die "impossible de fermer le fichier $!";
    return $res;
}

sub sign_in {
    open(my $handler,">>","account.txt");
    my ($mail, $nickname, $pass_word);
    do {
        print "enter mail : ";
        $mail = <STDIN>;
        chomp $mail;
    } until (defined($mail));
    do {
        print "enter nickname : ";
        $nickname = <STDIN>;
        chomp $nickname;
    } until (defined($nickname));
    do {
        print "enter password : ";
        ReadMode('noecho');
        $pass_word = <STDIN>;
        ReadMode('normal');
        chomp $pass_word;
        print "\n";
    } until (defined($pass_word));
    print $handler "\n$mail $nickname $pass_word";
    close($handler);
}

sub menu {
    my $login = shift;
    my $choice;
    my $leave = 0;
    do {
        print "-- Menu --\n";
        print "1 - encoder un fichier\n";
        print "2 - decoder un fichier\n";
        print "0 - quitter\n";
        $choice = <STDIN>;
        if ($choice == 1) {
            my $file;
            do {
                print "nom du fichier : ";
                my $nameFile = <STDIN>;
                chomp $nameFile;
                $file = glob("transfert/$nameFile");
            } until (-e $file && defined $file);
            my $extension;
            my ($namefile, $directories, $suffix) = fileparse($file);
            ($namefile, $extension) = split(/\./,$namefile,2);
            encoding $directories,$namefile,$extension,$login;
        } elsif ($choice == 2) {
            my $file;
            do {
                print "nom du fichier : ";
                my $nameFile = <STDIN>;
                chomp $nameFile;
                $file = glob("transfert/$nameFile");
            } until (-e $file && defined $file);
            my $extension;
            my ($namefile, $directories, $suffix) = fileparse($file);
            ($namefile, $extension) = split(/\./,$namefile,2);
            decoding $directories,$namefile,$extension,$login;
        } elsif ($choice == 0) {
            $leave = 1;
        } else {
            print "valeur inconnue\n"; 
        }
    } while ($leave != 1);
}

sub main {
    my $choice = undef;
    my $account;
    do {
        print "MaK Bloc Note\n-- Menu --\n";
        print "1 - Connection\n";
        print "2 - Inscription\n";
        $choice = <STDIN>;
        if ($choice == 1) {
            $account = login;
        }
        elsif ($choice == 2) {
            sign_in;
        }
        else { 
            print "valeur inconnue\n"; 
        }
    } while ($choice != 1);
    menu $account;
}

main;