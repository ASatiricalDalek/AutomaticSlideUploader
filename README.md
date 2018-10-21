# AutomaticSlideUploader
Created at CIDL to automatically upload slides to the website carousels


Purpose

The Website Slide Automator, much like the Digital Sign Scheduler, is designed to autonomously update the carousel slides on the website. It will automatically upload slides when they need to be uploaded, and remove them from the website when they need to be removed. This automation also extends to links on the slides, automatically applying a user-defined link to each image when that image is uploaded.


How it Works

The Website Slide Automator relies on two pieces to work properly: the script itself and the SlideshowCK Params module. SlideshowCK Params is a premium Joomla module which interfaces with the free SlideshowCK module, which runs all the slideshows on the website. This module allows the slideshow to automatically load a link and and image from a folder on the web server. See the section on SlideshowCK under the website documentation for more details on this process.

The script’s role is to scan the designated slides folder on the L:\ drive 
(L:\IT Department\WebsiteSigns\<Adults|Kids|Teens|Homepage>) 
and parse the file names for valid upload dates. If a valid upload date is found, the script SFTPs into the website and uploads the image, along with a text document of the same name specifying its URL, to the proper folder. 

Naturally, the script requires an administrator password to the website in order to complete this SFTP connection. While storing this password in plain text is a bad idea, the whole point of this script is to automate that entire process, so we need a way to access the password. To accomplish this, the password is encrypted using the windows account that the script will run from (in this case, the setup account on the ITLFile computer) and saved to a text file. Powershell then loads this password in via the file and converts it back into a readable password. No one without direct access to this machine and its account would be able to decrypt the password. 


How to Use

The script is set to run automatically via Windows Task Scheduler at 9 AM every day, on the ITLFile server. Due to password reasons detailed above, the script will only run successfully from this user account. If necessary, the script can be run manually without consequence, it will just result in a longer log file. 

From a user perspective, running the script is as simple as dropping the properly named files in the correct folders on the L:\ drive 
(L:\IT Department\WebsiteSigns\<Adult|Kids|Teens|Homepage>)
The naming convention is the upload date, in mmddyyyy format, followed by an underscore. Next is the friendly name of the file (Creative Coding Adventures, for example) which can include any character except an underscore. After the name is another underscore, followed by the removal date, formatted as mmddyyyy. 

A text file of the exact same name (except for the file extension of course) should also be placed in the folder, this will include a URL, where the user will be taken after clicking on the slide, and a target=_blank line which tells the web browser to open the link in a new tab. The final text file would look something like this


Link Text File Example 
    link=http://cidlibrary.evanced.info/EventDetails?EventId=9338&backTo=Calendar&startDate=2018/08/01
    target=_blank

To recap, each slide will have two files, which will look something like this:
07202018_Dungeons and Dragons_08162018.png
07202018_Dungeons and Dragons_08162018.txt

In this example we have a slide called Dungeons and Dragons, which will be uploaded to the website on July 20th 2018. On August 16th 2018, the slide will be deleted from the website, and thus removed from the carousel. The accompanying text file will contain a link to the program and a target=_blank line as specified above. 

Important Note: When slides get uploaded to the website they are deleted. Likewise, when a slide is removed from the website it is deleted, permanently. Do not put the only copy of an image in the website scheduler folder.


Troubleshooting

The Website Slide Automator generates log files for every file it parses through, which can be found on the L:\ drive at L:\IT Department\WebsiteSigns\Logs
These are dated in a YY.MM.DD format, so they stay organized by date. These logs show the name of the file, in addition to the date it is supposed to be removed/uploaded and tells what the script did with the file.

In the event of a failure to parse a file’s name, in addition to making an entry in the log, the script is designed to send an email to the webmaster account (webmaster@cidlibrary.org) from the tech@cidlibrary.org account. The details of the email, including who it is coming from and being sent to, in addition to its content, can be modified in the New-ErrorEmail function. 

There have been reported issues where the script has hard crashed Powershell due to a file not found exception. The cause of this hasn’t been pinned down but it also doesn’t seem to happen as often anymore so  ¯\_(ツ)_/¯
