// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;

int hexOfRGBA(int r, int g, int b, {double opacity = 1}) {
  r = (r < 0) ? -r : r;
  g = (g < 0) ? -g : g;
  b = (b < 0) ? -b : b;
  opacity = (opacity < 0) ? -opacity : opacity;
  opacity = (opacity > 1) ? 255 : opacity * 255;
  r = (r > 255) ? 255 : r;
  g = (g > 255) ? 255 : g;
  b = (b > 255) ? 255 : b;
  int a = opacity.toInt();
  return int.parse(
      '0x${a.toRadixString(16)}${r.toRadixString(16)}${g.toRadixString(16)}${b.toRadixString(16)}');
}

void main(List<String> arguments) => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'WebSocket Demo';
    return const MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;
  late three.Mesh mesh;

  List<dynamic> data = [];
  var cubeList = [];

  double dpr = 1.0;

  bool disposed = false;

  late three.Object3D object;

  late three.Texture texture;

  late three.WebGLRenderTarget renderTarget;

  dynamic sourceTexture;

  bool loaded = false;

  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = width;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await three3dRender.initialize(options: options);

    setState(() {});

    // TODO wait until DOM is ready
    Future.delayed(const Duration(milliseconds: 200), () async {
      await three3dRender.prepareContext();

      initScene();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Occupation Map Visualization"),
      ),
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return SingleChildScrollView(child: _build(context));
        },
      ),
    );
  }

  Widget _build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
                width: width,
                height: height,
                color: Colors.red,
                child: Builder(builder: (BuildContext context) {
                  if (kIsWeb) {
                    return three3dRender.isInitialized
                        ? HtmlElementView(
                            viewType: three3dRender.textureId!.toString())
                        : Container(
                            color: Colors.orange,
                          );
                  } else {
                    return three3dRender.isInitialized
                        ? Texture(textureId: three3dRender.textureId!)
                        : Container(color: Colors.orange);
                  }
                }))
          ],
        ),
      ],
    );
  }

  render() {
    renderer!.render(scene, camera);

    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }

  initRenderer() {
    Map<String, dynamic> options = {
      "width": width,
      "height": height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element
    };

    print('initRenderer  dpr: $dpr _options: $options');

    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({"format": three.RGBAFormat});
      renderTarget = three.WebGLRenderTarget(
          (width * dpr).toInt(), (height * dpr).toInt(), pars);
      renderTarget.samples = 4;
      renderer!.setRenderTarget(renderTarget);

      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
    }
  }

  initScene() {
    initRenderer();
    initPage();
  }

  initPage() async {
    /// Connect to WebSocket channel
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.14:1234'),
    );

    final double viewportWidth = width * dpr;
    final double viewportHeight = height * dpr;

    scene = three.Scene();
    camera =
        three.PerspectiveCamera(90, viewportWidth / viewportHeight, 0.1, 1000);

    final ambientLight = three.AmbientLight(0xffffff, 0.9);
    scene.add(ambientLight);

    camera.position.z = 50;
    camera.position.y = 30;
    camera.position.x = 30;
    camera.viewport = three.Vector4(three.Math.floor(0), three.Math.floor(0),
        three.Math.ceil(viewportWidth), three.Math.ceil(viewportHeight));

    camera.updateMatrixWorld(false);

    /// Listen for incoming data
    channel.stream.listen(
      (dataReceived) {
        data = jsonDecode(dataReceived);

        var geometry = three.BoxGeometry(1, 1, 1);
        cubeList = List.generate(
            60,
            (i) => List.generate(
                60,
                (i) => three.Mesh(
                    geometry, three.MeshPhongMaterial({"color": 0x00ff00ff})),
                growable: false),
            growable: false);

        for (int y = 0; y < 60; y++) {
          for (int x = 0; x < 60; x++) {
            scene.add(cubeList[y][x]);

            cubeList[y][x].position.y = y;
            cubeList[y][x].position.x = x;
            // cubeList[y][x].position.z = 0;
          }
        }

        animate(1);
      },
      onError: (error) => print(error),
    );

    loaded = true;
  }

  animate(frame) {
    if (!mounted || disposed) {
      return;
    }

    if (!loaded) {
      return;
    }
    for (int y = 0; y < 60; y++) {
      for (int x = 0; x < 60; x++) {
        var material = three.MeshPhongMaterial({
          "color": hexOfRGBA(
              (128 +
                      double.parse(data[frame]["data_${(60 * y + x)}"]) *
                          256 /
                          100)
                  .round(),
              (255 -
                      double.parse(data[frame]["data_${(60 * y + x)}"]) *
                          128 /
                          100)
                  .round(),
              90)
        });
        cubeList[y][x].material = material;
      }
    }

    render();

    Future.delayed(const Duration(milliseconds: 20), () {
      if (frame > 207) frame = 1;
      animate(frame + 1);
    });
  }

  @override
  void dispose() {
    disposed = true;
    three3dRender.dispose();

    super.dispose();
  }
}
