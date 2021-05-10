# About
An iOS example project for janus videoroom-plugin, written in Swift.

## Features

- 1 to many video conference;
- camera sharing;
- screen sharing(currently video only).

## Screenshots

![Video Room](resource/screenshot%402x.png)

## Notice

- This repo is for sharing my learning WebRTC & janus video room experience, welcome to share yours.
- This is an example project and far from a demo, it is not fully test yet, welcome to create an issue.

## Steps

- Connect signaling server first(specific in `Config.signalingServerURL`), 
for example: `wss://janus.conf.meetecho.com/ws` or build your own janus sever.
- Input room number(such as: 1234), `1234` is higly recommended.
- Hit `Join Room`, will joined the video room if nothing goes wrong.

## Sequence Diagram

- Uploading...

## External Libraries & their licenses
- [WebRTC](https://github.com/Meonardo/WebRTC.git).
- [Starscream](https://github.com/daltoniam/Starscream).
- [Codextended](https://github.com/JohnSundell/Codextended). 
- [Alertift](https://github.com/sgr-ksmt/Alertift).
- [ProgressHUD](https://github.com/relatedcode/ProgressHUD)
