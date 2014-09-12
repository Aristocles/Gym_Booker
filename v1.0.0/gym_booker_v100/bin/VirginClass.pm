# Virgin Active Health Club. This is a class to define a gym class/session.
# Written to work woth gym_booker program written by Eddy jayaristocles@gmail.com.au
# www.makeitbreakitfixit.com
#
# Information it expects:
# 1)  Class number - This is just a linear number created by the script and is the nth class the
#     scipt is handling.
# 2)  HREF/URL - URL to book this class
# 3)  Name - of class
# 4)  Time - the class starts (in 24 hours)
# 5)  Length - of time the class runs for (minutes)
# 6)  Location,- of the class (name of room at the gym)
# 7)  Instructor - taking the class
# 8)  Hot flag - Whether the class is considered a 'hot' class or not (BOOL)
# 9)  Date - of the class
# 10) Status - Amount of space left in the class (GREEN, ORANGE, RED, or BLACK)
#              BLACK = no space left/booked out
#

package VirginClass;
use strict;
use POSIX;

our $VERSION = 1.0;

my $name;

sub new {
  my $class = shift;
  my $self = {
    _classNum   => shift,
    _url        => shift,
    _name       => shift,
    _time       => shift,
    _length     => shift,
    _location   => shift,
    _instructor => shift,
    _hot        => shift,
    _date       => shift,
    _state      => shift
  };
  # ------- Sanitise the data before storing in the class -------
  # THere are one of 4 states denoted by hex colour. We translate colour to the name
  $self->{_state} = "GREEN"  if ($self->{_state} eq '00a300'); # Plenty of space left in class
  $self->{_state} = "RED"    if ($self->{_state} eq 'ff0000'); # Little space left in class
  $self->{_state} = "BLACK"  if ($self->{_state} eq '000000'); # No space left in class
  $self->{_state} = "ORANGE" if ($self->{_state} eq 'ff8200'); # Moderate amount of space left in class

  # Time is converted to 24 hour
  if ($self->{_time} =~ m/(\d+):(\d+)([AP]M)/) {
    my $hrs  = $1;
    my $mins = $2;
    my $ampm = $3;
    $hrs += 12                          if ($ampm eq "PM" && $hrs < 12);
    $self->{_time} = "0" . $hrs . $mins if ($hrs < 10);
    $self->{_time} = $hrs . $mins       if ($hrs >= 10);
  } else {return 0;} # Failed to create object, return err

  # Create the instance of the class and return its hash reference
  bless $self, $class;
  return $self;
}

# Change the name of the class, if needed
sub setName {
  my ($self, $name) = @_;
  $self->{_name} = $name if defined($name);
  return $self->{_name};
}

# Change the time the class runs, if needed (24 hour time only)
sub setTime {
  my ($self, $time) = @_;
  $self->{_time} = $time if ($time > 0 && $time < 2400); # Really dodgy check
  return $self->{_time};
}

# Change the location of the class, if needed
sub setLocation {
  my ($self, $location) = @_;
  $self->{_location} = $location if defined($location);
  return $self->{_location};
}

# Change the instructor for the class, if needed
sub setInstructor {
  my ($self, $instructor) = @_;
  $self->{_instructor} = $instructor if defined($instructor);
  return $self->{_instructor};
}

# Basic subroutines to return class information
sub getClassNum   {my $self = shift; return $self->{_classNum  };}
sub getURL        {my $self = shift; return $self->{_url       };}
sub getName       {my $self = shift; return $self->{_name      };}
sub getTime       {my $self = shift; return $self->{_time      };}
sub getLength     {my $self = shift; return $self->{_length    };}
sub getLocation   {my $self = shift; return $self->{_location  };}
sub getInstructor {my $self = shift; return $self->{_instructor};}
sub getHot        {my $self = shift; return $self->{_hot       };}
sub getDate       {my $self = shift; return $self->{_date      };}
sub getStatus     {my $self = shift; return $self->{_state     };}

# Print to stdout a pretty ASCII representation of all the data
sub printFull {
  my $self = shift;
  printf("\n ____________________ Class %-4d - %-11s ___________________\n", $self->{_classNum}, $self->{_date});
  printf("|%-10s: %-22s %-8s: %-8s", "Name", $self->{_name}, "Status", $self->{_state});
  printf("**HOT**") if ($self->{_hot} != 0);
  printf("\n");
  printf("|%-10s: %-12s %-8s: %-22s\n", "Instructor", $self->{_instructor}, "Location", $self->{_location});
  printf("|%-10s: %-4s (%smins)\n", "Time", $self->{_time}, $self->{_length});
  printf("|%s\n", $self->{_url});
  printf("\\_________________________________________________________________\n");
}

# Compares user preferences with class information and returns URL to book the class if found.
sub findMatch {
  my $self = shift;
  my $prefs = {
    thisTime => shift,
    minTime  => shift,
    maxTime  => shift,
    days     => shift,
    names    => shift
  };
  my $matcher = 0; # Used to match all the aspects of the user preferences.
  # Time (range), day (range), and class name (1 or many).

  #printf("Given. %s %s %s %s\n", $prefs->{thisTime}, $prefs->{minTime}, $prefs->{maxTime}, $prefs->{days});

  # ------- Compare class time to user preference -------
  # Calculate the time range (max and min time)
  $prefs->{thisTime} =~ m/(\d\d?)(\d\d)$/;
  my ($newMin, $newHrs, $tmp, $hrs, $min);
  $hrs = $1; # Pull out hours and mins from the time
  $min = $2;
  $tmp = ((($hrs * 60) + $min) - $prefs->{minTime});
  $newMin = num($tmp % 60); # Calculate number of minutes in new min time
  $newHrs = num(floor($tmp / 60)); # and number of hours in new time
  $prefs->{minTime} = $newHrs . $newMin; # Add them together
  #
  $tmp = ((($hrs * 60) + $min) + $prefs->{maxTime}); # Same thing as above, but with max time
  $newMin = num($tmp % 60); # Calculate number of minutes in new min time
  $newHrs = num(floor($tmp / 60)); # and number of hours in new time
  $prefs->{maxTime} = $newHrs . $newMin;
  if ($prefs->{minTime} < 0 || $prefs->{maxTime} > 2359) {
    printf("[ERR] The time range given falls outside of a full day, skipping. - Min: %s Max: %s\n", 
      $prefs->{minTime}, $prefs->{maxTime});
    return 0;
  }
  # Compare user time range to class time. Increment matcher if match found.
  if ($prefs->{minTime} <= $self->{_time} && $prefs->{maxTime} >= $self->{_time}) {
    $matcher++;
#    printf("              ------- [MATCHER %d] Time range converted to %s -> %s (24 hours)\n", $matcher, $prefs->{minTime}, $prefs->{maxTime});
  }


  # ------- Compare class day to user preference -------
  # Pull out the 3 char day this class is running on
  my $day;
  if ($self->{_date} =~ m/^(\w+)/) {
    $day = $1;
  }
  SWITCH: { # Translate the day in to a regex search string
    if ($day eq "Mon") {$day = '1......'; last SWITCH;}
    if ($day eq "Tue") {$day = '.1.....'; last SWITCH;}
    if ($day eq "Wed") {$day = '..1....'; last SWITCH;}
    if ($day eq "Thu") {$day = '...1...'; last SWITCH;}
    if ($day eq "Fri") {$day = '....1..'; last SWITCH;}
    if ($day eq "Sat") {$day = '.....1.'; last SWITCH;}
    if ($day eq "Sun") {$day = '......1'; last SWITCH;}
    printf("[ERR] Day the class is running does not match what we expect. - Day: %s\n", $day);
    return 0; # Err is code reaches here
  }
  # Compare the preferred day(s) to the class day. Increment matcher if match found.
  if ($prefs->{days} =~ qr/$day/) {
    $matcher++;
#    printf("              ------- [MATCHER %d] Day from site is: %s, and comparing to user pref: %s\n", $matcher, $day, $prefs->{days});
  }


  # ------- Compare class name to user preference -------
  for my $classNames ($prefs->{names}) { # A reference to an array is passed to us
    foreach (@$classNames) { # so we deference it and iterate through the user pref classes
      #printf("       Comparing %s to %s\n", $_, $self->{_name});
      if ($self->{_name} =~ qr/$_/i) {
        $matcher++;
#        printf("              ------- [MATCHER %d] %s matches to %s\n", $matcher, $_, $self->{_name});
        last; # Need to break out of the loop if match is found to prevent other names may match and artificially increase $matcher
      }
    }
  }

  if ($matcher == 3) {
    printf("Attempting to book class... ");
#    printf("***************************************** MATCH FOUND, returning URL\n");
    if ($self->{_state} eq "BLACK") {
      $self->printFull;
      printf("Failed. The class is full.\n\n\n");
      return 0;
    }
    $self->printFull;
    return $self->{_url}; # If all is well, we return the booking URL
  }

}

# Accepts a scalar number. If it is below 10 it returns the number
# with a preceding 0. eg. 9 will be returned as 09.
sub num {
  my $num = shift;
  return ("0" . $num) if ($num < 10);
  return $num;
}

1;

