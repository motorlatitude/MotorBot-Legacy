[![MotorbotHeader](https://github.com/motorlatitude/MotorBot/blob/develop/motorbotHeader.png?raw=true)]()


[![Github Issues](https://img.shields.io/github/issues/motorlatitude/motorbot.svg?style=flat-square)]() &nbsp; &nbsp;
[![Build Status](https://img.shields.io/travis/motorlatitude/MotorBot.svg?branch=master&style=flat-square)](https://travis-ci.org/motorlatitude/MotorBot) &nbsp; &nbsp;
[![GitHub release](https://img.shields.io/github/release/motorlatitude/motorbot.svg?style=flat-square)]() &nbsp; &nbsp;
[![Requirements Status](https://img.shields.io/requires/github/motorlatitude/MotorBot.svg?branch=develop^style=flat-square)](https://requires.io/github/motorlatitude/MotorBot/requirements/?branch=develop) &nbsp; &nbsp;
[![Chrome Web Store](https://img.shields.io/chrome-web-store/v/pgkdpldhnmmhpdfmmkgpnpofaaagomab.svg?style=flat-square)]()


MotorBot is a bot designed for discord, built on the [Node.js](https://nodejs.org/) javascript runtime environment. It allows
for an easy and flexible integration of other API's or commands to make the bot personal.

## Features
MotorBot has a number of features that it can do right out of the box;
 - Join and Leave Voice Channels
 - Play music from youtube via a nice  browser interface
 - API for music playback to create your own interfaces
 - Soundboard - play sound effects in voice channels
 - Heads Or Tails
 - Rock, Paper, Scissors
 - Get Reddit stories from r/all or custom subs
 
&nbsp;

## DiscordClient Library
MotorBot uses a custom written library the DiscordClient Library. This 
library is built on [Node.js](https://nodejs.org/) which allows the interaction with [Discords API](https://discordapp.com/developers/docs/). The library is currently
integrated within this project with plans of making it a separate node module. Currently,
the library and its relevant files are located in the [discordClient directory](https://github.com/motorlatitude/MotorBot/tree/master/discordClient). 

- [DiscordClient Library Documentation](https://motorlatitude.github.io/MotorBot/discordclient/#introduction/overview)