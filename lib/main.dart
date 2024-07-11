import 'dart:io';

import 'package:easy_tv_live/channel_drawer_page.dart';
import 'package:easy_tv_live/mobile_video_widget.dart';
import 'package:easy_tv_live/subscribe/subscribe_page.dart';
import 'package:easy_tv_live/table_video_widget.dart';
import 'package:easy_tv_live/util/log_util.dart';
import 'package:easy_tv_live/util/m3u_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:sp_util/sp_util.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  LogUtil.init(isDebug: false, tag: 'EasyTV');
  await SpUtil.getInstance();
  runApp(const MyApp());
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '极简TV',
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Kaiti', useMaterial3: true),
      routes: {'subScribe': (BuildContext context) => const SubScribePage()},
      home: const LiveHomePage(),
      builder: EasyLoading.init(),
    );
  }
}

class LiveHomePage extends StatefulWidget {
  const LiveHomePage({super.key});

  @override
  State<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends State<LiveHomePage> {
  String toastString = '正在加载';

  Map<String, dynamic>? _videoMap;

  String _group = '';
  String _channel = '';
  int _sourceIndex = 0;

  VideoPlayerController? _playerController;

  bool isBuffering = false;

  bool isPlaying = false;
  double aspectRatio = 1.7777777777777777;

  _playVideo() async {
    setState(() {
      toastString = '正在播放：$_channel';
    });
    final url = _videoMap![_group][_channel][_sourceIndex].toString();
    debugPrint('正在播放:::$url');
    if (_playerController != null) {
      await _playerController?.dispose();
      _playerController = null;
      setState(() {});
    }
    _playerController = VideoPlayerController.networkUrl(Uri.parse(url),
        formatHint: VideoFormat.hls,
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
          webOptions:
              const VideoPlayerWebOptions(controls: VideoPlayerWebOptionsControls.enabled()),
        ))
      ..setVolume(1.0);

    try {
      await _playerController!.initialize();
      _playerController!.play();
      setState(() {
        toastString = '正在加载';
        aspectRatio = _playerController!.value.aspectRatio;
      });
    } catch (e) {
      final channels = _videoMap![_group][_channel];
      _sourceIndex += 1;
      if (_sourceIndex > channels.length - 1) {
        _sourceIndex = 0;
        setState(() {
          toastString = '此视频无法播放';
        });
      } else {
        setState(() {
          toastString = '尝试切换线路${_sourceIndex + 1}...';
        });
        Future.delayed(const Duration(seconds: 2), () => _playVideo());
        return;
      }
    }
    _playerController!.addListener(() {
      if (_playerController!.value.hasError) {
        final channels = _videoMap![_group][_channel];
        _sourceIndex += 1;
        if (_sourceIndex > channels.length - 1) {
          setState(() {
            toastString = '此视频无法播放，请更换其它频道';
          });
          return;
        } else {
          setState(() {
            toastString = '切换线路${_sourceIndex + 1}...';
          });
          Future.delayed(const Duration(seconds: 2), () => _playVideo());
          return;
        }
      }
      if (isBuffering != _playerController!.value.isBuffering) {
        setState(() {
          isBuffering = _playerController!.value.isBuffering;
        });
      }

      if (isPlaying != _playerController!.value.isPlaying) {
        setState(() {
          isPlaying = _playerController!.value.isPlaying;
        });
      }
    });
  }

  _onTapChannel(String group, String channel) {
    _group = group;
    _channel = channel;
    _sourceIndex = 0;
    _playVideo();
  }

  @override
  void initState() {
    super.initState();
    EasyLoading.instance
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorColor = Colors.black
      ..textColor = Colors.black
      ..backgroundColor = Colors.white70;
    _parseData();
  }

  @override
  dispose() {
    WakelockPlus.disable();
    _playerController?.dispose();
    super.dispose();
  }

  _parseData() async {
    final resMap = await M3uUtil.getDefaultM3uData();
    _videoMap = resMap;
    _group = _videoMap!.keys.first.toString();
    _channel = Map.from(_videoMap![_group]).keys.first;
    _sourceIndex = 0;
    _playVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: OrientationLayoutBuilder(
        portrait: (context) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          return MobileVideoWidget(
            toastString: toastString,
            controller: _playerController,
            changeChannelSources: _changeChannelSources,
            isLandscape: false,
            isBuffering: isBuffering,
            isPlaying: isPlaying,
            aspectRatio: aspectRatio,
            onChangeSubSource: _parseData,
            drawChild: ChannelDrawerPage(
                videoMap: _videoMap,
                channelName: _channel,
                groupName: _group,
                onTapChannel: _onTapChannel,
                isLandscape: false),
          );
        },
        landscape: (context) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          return WillPopScope(
            onWillPop: () async {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ]);
              return false;
            },
            child: Scaffold(
              drawer: ChannelDrawerPage(
                  videoMap: _videoMap,
                  channelName: _channel,
                  groupName: _group,
                  onTapChannel: _onTapChannel,
                  isLandscape: true),
              drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.3,
              body: TableVideoWidget(
                  toastString: toastString,
                  controller: _playerController,
                  isBuffering: isBuffering,
                  isPlaying: isPlaying,
                  aspectRatio: aspectRatio,
                  changeChannelSources: _changeChannelSources,
                  isLandscape: true),
            ),
          );
        },
      ),
    );
  }

  _changeChannelSources() async {
    List sources = _videoMap![_group][_channel];
    final selectedIndex = await showModalBottomSheet(
        context: context,
        barrierColor: Colors.transparent,
        backgroundColor: Colors.black87,
        builder: (BuildContext context) {
          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
              color: Colors.transparent,
              child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(sources.length, (index) {
                    return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(
                                color: _sourceIndex == index ? Colors.red : Colors.white)),
                        child: Text(
                          '线路${index + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              color: _sourceIndex == index ? Colors.red : Colors.white),
                        ),
                        onPressed: () {
                          Navigator.pop(context, index);
                        });
                  })),
            ),
          );
        });
    if (selectedIndex != null) {
      _sourceIndex = selectedIndex;
      debugPrint('切换线路:====线路${_sourceIndex + 1}');
      _playVideo();
    }
  }
}
