Gym_Booker
==========

Book classes automatically for Virgin Active gym

####################################################################################
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################

Gym Booker was written by Eddy (jayaristocles@gmail.com) www.makeitbreakitfixit.com - 12/Sep/2014

Gym Booker is specifically designed for Virgin Active Health Club class scheduling system, in Australia.
The current system allows members to book up to 8 days in advance. With the 8th day schedule being released at 8pm each night.
This script is designed to be run just after 8pm (via cron) and it will scrape the classes. Then, according to a pre-configured cfg file, will book your specified classes.
The Virgin Active site then sends a confirmation email to you.

You never need to miss out on a class again!

REQUIREMENTS
- Linux or Unix-like Operating System with PERL 5.x and CRON (or other scheduler)


INSTALLATION
- Decompress .the zip file in your home directory
- Edit the file config/gym_booker.cfg with your membership ID, password, and classes you wish to book
- Be sure that bin/session_grab.pl is executable (chmod +x bin/session_grab.pl)
- Add an entry in your cron to execute the script just after 8pm every night
(eg. crontab -e; add the line "10 20 * * * /var/www/gym_booker/bin/session_grab.pl | logger" in to cron)

Any questions, bugs or other issues. Email me.

