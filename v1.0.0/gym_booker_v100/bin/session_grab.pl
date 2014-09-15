#!/usr/bin/perl
#
#
# -------------- Virgin Active Class Session Grabber -------------- v1.0.1
# Created by Eddy - JayAristocles@gmail.com - www.makeitbreakitfixit.com - 09/2014
#
# Virgin Active health club allows bookings of its classes up to 7 days in advance,
# some classes are very popular and almost immediately are booked out. This script
# is designed to load the 7th day class schedule as soon as it is released (likely
# at midnight, the script will immediately look for the classes so timing is adjusted
# using execution time of the script. ie. cron jobs).
# Once the schedule is downloaded the script will automatically book sessions for
# classes using predetermined classes and times to look for.
# The Virgin Active 'My Locker' page (members page where you can book classes) then
# emails me automatically to confirm booking.
#
# Main functions of this script:
# - Log in to My Locker
# - Grab class list
# - Book classes according to time/class set by user
#
# BUG FIXES / CHANGES:
#
# v1.0.1
# - Added message to inform user of booking failure due to too many classes being booked
# - Site shows 8 days in advance if past 8pm, otherwise just 7 days. This would break the
#   script so added some code to fix it.
# - Added a little colour to the stdout text to make it look pretty


use strict;
use warnings;
use Term::ANSIColor;
#use diagnostics;

use VirginClass;
use WWW::Mechanize;
use LWP::UserAgent;
use HTTP::Request;
use Time::Local;
use POSIX;
use Scalar::Util qw(looks_like_number);

main();

sub main {
  print color 'bold blue'; # Colourful text! wee!
  printf("******* Running $0 *******\n");
  print color 'reset'; # Back to boring text
  ###########################################################################################
  # Below variable is the only one that needs to be customised. All other config should be
  # changed within the puncher cfg file.
  my $configFile = "../config/gym_booker.cfg";
  ###########################################################################################

  ####### Global Variables #######
  my $domain = "http://mylocker.virginactive.com.au/mobile/login.aspx"; # All plain text HTTP (no SSL). Nice :)
#  my $domain = "http://vorignet.com/test/"; # Testing
  my $today = timelocal(localtime()); # time given as epoch # print "today is $today\n";
  my($day, $month, $year)=(localtime)[3,4,5];
  $year += 1900;
  $month += 1;
  ###########################################################################################

  ####### Pull configuration from config file #######
  my @cfg;
  open (CFG_IN, "<$configFile"); # Pull out entire contents of config file
  @_ = <CFG_IN>;
  foreach (@_) { # Create new array with contents of config file, sans comments
    my @split = split(/=/, $_) unless (($_ =~ m/^\#/) || ($_ =~ m/^\s+$/)); # Split the config lines by the = sign too
    foreach (@split) {
      $_ =~ s/^\s+|\s+$//g; # also, remove whitespace
      push @cfg, $_;
    }
  close (CFG_IN);  
  }
  my ($myMemberID, $myPassword);
  my @myClasses;
  for (my $i = 0; $i < @cfg; $i++) { # Now we can pull the config we need
    push @myClasses, $cfg[$i+1] if ($cfg[$i] eq "Class"); # Each element contains a pipe ( | ) delimited list of class info
    $myMemberID = $cfg[$i+1] if ($cfg[$i] eq "MemberID");
    $myPassword = $cfg[$i+1] if ($cfg[$i] eq "Password");
  }

  # Each 'Class' line contained pipe-delimited data, we break this out here.
  # Each 'Class' line must contain 5 elements, with the last one being an optional
  # comma-separated list
  my @allClasses;

  for (my $i = 0; $i < @myClasses; $i++) {
    my @split = split(/\|/, $myClasses[$i]); # Split the line by pipe
    foreach (@split) {$_ =~ s/^\s+|\s+$//g;} # Remove whitespace
    my $classNames = pop @split; # Pulls out last element (command-delimited class list) and put in scalar
    my @names = split(/,/, $classNames); # Split this list out in to an array
    foreach (@names) {$_ =~ s/^\s+|\s+$//g;} # Remove whitespace
    push(@split, [ @names ]); # Add the list of classes as last element of list
    push(@allClasses, [ @split ]); # This array holds another array which holds scalars and an array
  }
  # At this point we have a 3 level nested array which looks like this:
  #
  # ArrayOfClassesToSchedule(list)
  #      |[0]Schedule(list)
  #           |[0]Time(scalar)   [1]TimeBefore(scalar)    [2]TimeAfter(scalar)   [3]Days(scalar)   [4]ClassNames(list)
  #                                                                                                     |[0]Name(scalar)  [0]Name(scalar)
  #      |[1]Schedule(list)
  #           |[0]Time(scalar)   [1]TimeBefore(scalar)    [2]TimeAfter(scalar)   [3]Days(scalar)   [4]ClassNames(list)
  #                                                                                                     |[0]Name(scalar)
  #      |[2]Schedule(list)
  #           |[0]Time(scalar)   [1]TimeBefore(scalar)    [2]TimeAfter(scalar)   [3]Days(scalar)   [4]ClassNames(list)
  #                                                                                                     |[0]Name(scalar)  [1]Name(scalar)  [2]Name(scalar)
  printf("%-3s] %-10s %-11s %-7s  %s\n", "No.", "Time", "-/+ mins", "MTWTFSS", "Class Names");
  my $count;
  for my $classCfg (@allClasses) {
    $count++;
    printf("%-3s] %-10s -%-3d / +%-3d %-7s  ", $count, $$classCfg[0], $$classCfg[1], $$classCfg[2], $$classCfg[3]);
    for my $classNames ($$classCfg[4]) {
      foreach (@$classNames) {
        print("$_, ");
      }
      print("\n");
    }
  }
  print("$count lines read in from $configFile.\n\n");
  ###########################################################################################
  ###########################################################################################

  # ------- Scrap the website for data we need -------
  my $mech = WWW::Mechanize->new(agent =>
    'Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19
     (KHTML, like Gecko) Chrome/18.0.1025.166  Safari/535.19');
  # User agent must be for a mobile device, to avoid Javascript limitations when getting class information later
  # print ($mech->known_agent_aliases()); # Prints list of known user agents

  # Log in to website first
  $mech->get($domain);
  my $numOfFields = 2; # Expect two fields. Username and password, only.
  if ($mech->set_visible($myMemberID, $myPassword) != $numOfFields) {
    print("[ERR] - Unable to log in\n");
    exit 0;
  }
  $mech->click(); # Submit the form

  # Navigate to appropriate page
  my $response = $mech->follow_link(url_regex => qr/bookaclass/i); # Finds a link with 'bookaclass' in it, follows it
  my @content = getContent($response); # Holds the HTTP page with booking menu in it

  #print($mech->response->as_string); # Debug - Print HTML response to screen

  # The booking page will display 7 days in advance, but will show you the 8th day after 8pm.
  # This presents a slight problem when choosing which day to select, if we pick 8th day and
  # the form doesn show that day, then we get an error. $mech->select() doesnt help with its
  # return codes (always showing TRUE, even when option is not present). So instead we will
  # parse the HTTP page and scrape the number of days (options) are available, and pick the
  # last one.
  my $daysCounter = 0; # Used to store the number of days in to the future we can see the class schedule
  for (my $x = 0; $x < $#content; $x++) {
    if ($content[$x] =~ m/ctl00\$ctl00\$phPage\$phPage1\$ddlDate/) { # Fine the correct HTTP <select>
      while($content[$x+1] =~ m/<option/) { # Iterate the counter per HTTP <option> tag found
        $x++;
        $daysCounter++;
      }
    }
  }
  print("Found classes up to " . ($daysCounter - 1) . " days in advance\n") if ($daysCounter)
    || die ("[ERR] Couldn't find form object to select day to view classes\n");

  $mech->submit_form( # Select the day from the dropdown list box
    with_fields => {
      'ctl00$ctl00$phPage$phPage1$ddlDate' => ($daysCounter - 1)
    }
  );
  $response = $mech->click(); # Submit the form, retrieve response


  # ------- Iterate through the returned content and pull out all the classes -------
  my @classes = getContent($response); # Holds the HTTP page with list of classes in it
  my $numOfClasses = 0;
  my @siteClasses;
  my $date;
  for (my $i = 0; $i < $#classes; $i++) {
    # Each class is defined with lineitem HTML tags <li> and </li>. We look for these and iterate
    # within each tag pair to pull needed data.
    if ($classes[$i] =~ m/Pitt Street Mall<.+?>([\w\s]+)<\/h1>/) {
      $date = $1;
    }
    if ($classes[$i] =~ m/<li id=".*listItem_([\d]+)" .*solid #(\w+);">/) { # Look for the lineitem <li> for a class
      my ($href, $name, $time, $length, $location, $instructor, $status) = "";
      my $hot = 1; # 'hot' class by default
      $status = $2;
      last unless ($numOfClasses == $1); # Break the loop if the listitem number doesnt match what we expect
      $numOfClasses++;
      while ($classes[$i] !~ m/^\s*<\/li>\s*$/) { # Keep iterating until we read the end of the </li>
        # Grab all the class information from the next few lines in HTTP content
        if ($classes[$i] =~ m/^\s*<a.* href="(.*)">/)                     {$href = $1;} # Booking URL
        if ($classes[$i] =~ m/^\s*<h1 style=.*?>([\w\s\-\/]+).*?<\/h1>/)  {$name = $1;} # Class name
        if ($classes[$i] =~ m/^\s*<p class="\w+">(\d+:\d+[AP]M).*?(\d+)/) {$time = $1; $length = $2;} # Run length & start time
        if ($classes[$i] =~ m/^\s*<p>([\w\s]+)\s*\/\s*([\w\s-]+?)<\/p>/)  {$location = $1; $instructor = $2;} # Room & Instructor
        $hot = 0 if ($classes[$i] =~ m/visibility:hidden/); # Disable flag if hot icon is hidden
        $i++; # Keep iterating the existing 'for' loop
      }

      # Instantiate a VirginClass object and feed it all the data
      my $entry = VirginClass->new(
        $numOfClasses, $href, $name, $time, $length,
        $location, $instructor, $hot, $date, $status
      );
      push(@siteClasses, $entry); # Push the object on to an array of classes
    }
  }
  print("Number of classes: $numOfClasses for $date\n");
  # At this point, all data collection is complete and stored in an array of objects

  # We pass the user class preferences to the object and the object will either return a URL
  # for the [first] match it found, or return an error to signify no match or other error.
  # Each class preference line (in the config file) will only match one class, if found.
  my $found;
  my $bookings = 0;
  foreach my $e (@siteClasses) {
#    printf("SCHEDULE CLASS - %s at %s\n", $e->getName, $e->getTime);
    #$e->printFull; # Print to screen the class details
    for my $classCfg (@allClasses) {
#      printf("       PREFERENCES - %s\n", $$classCfg[0]);
      if ($found = $e->findMatch($$classCfg[0], $$classCfg[1], $$classCfg[2], $$classCfg[3], $$classCfg[4])) {
#        printf("                        -----   Found a match, URL is: %s\n", $found);
        if (bookClass($found, $mech)) { # If booking is successful
          undef $$classCfg[4]; # Undefine all class names in user pref, to prevent any further matches
          $bookings++;
        }
      }
    }
  }
  printf("\nDONE. Successfully booked %d class(es)\n", $bookings);
  print color 'bold blue'; printf("******* Ending $0 *******\n"); print color 'reset';
}

# Expects the URL and the Mechanize object. Using the URL will GET it and then book the class.
# TODO: Modify to accept another argument of the class details it booked, then display these details.
sub bookClass {
  my $url = shift;
  my $mech = shift;
  if ($mech->uri() =~ m/^(.*\/)[\w.?=]+$/) {
    $url = $1 . $url;
    my $response = $mech->get($url);
    my $content = $response->as_string;
    if ($content =~ m/name="(.*)" value="book"/) {
      $response = $mech->submit_form(button => $1);
      if ($response->is_success) {
        $content = $response->as_string;
        print color 'bold green'; # Change text colour
        printf("SUCCESS! Class booked, check email for confirmation.\n\n\n") if ($content =~ m/<h1>Success<\/h1>/);
        print color 'reset'; # Text back to standard
        return 1;
      } else {printf("Failed. Undefined response. Check email to see if you are booked.\n");}
    } else {
      print color 'bold red'; # Change text colour
      printf("Failed.");
      printf(" You are already booked for this class.\n")      if ($content =~ m/No need to book,/);
      printf(" Double-booking. Delete other booking first.\n") if ($content =~ m/This class clashes/);
      printf(" You have too many booked classes.\n")           if ($content =~ m/you love our classes/);
      print color 'reset'; # Text back to standard
    }
  } else {printf("Failed. There was a problem parsing the URL to book the class\n");}
  printf("\n\n");
  return 0;
}

# Expects a HTTP::Response object and returns an array, each element is a line in the HTTP response.
# Exits script on failure.
sub getContent {
  my $response = shift;

  if ($response->is_success) {
    my $content = $response->as_string;
    my @c = split /\n/, $content; # Otherwise return as an array (split by newline)
    return @c;
  } else {
    print("[ERR] Unable to extract HTTP page from response\n");
    exit 0;
  }
}
