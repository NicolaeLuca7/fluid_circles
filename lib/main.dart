import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_processing/flutter_processing.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class MyColor {
  MyColor(Color cl) {
    color = cl;
  }

  Color color = Colors.black;
}

class Circle {
  double X = 0, Y = 0, radius = 0;

  Circle(this.X, this.Y, this.radius);
}

class Point {
  double X = 0, Y = 0;
  Point(this.X, this.Y);
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  double X1 = 0,
      Y1 = 0,
      XO = 0,
      YO = 0,
      radiusO = 1,
      radprev = 1,
      lineweight = 4.0,
      circleweight = 4.0,
      speed = 150,
      eraserradius = 5,
      maxspeed = 240,
      minspeed = 60,
      changingspeed = 1;
  int dir = 1, ix = 0, nr = 0;
  double appheight = 0, appwidth = 0;
  MyColor backgroundcl = MyColor(Colors.black),
      strokecl = MyColor(Color.fromARGB(255, 255, 17, 0)),
      fillcl = MyColor(Colors.black),
      uicolor = MyColor(Color.fromARGB(255, 255, 17, 0));
  Sketch sketch = Sketch();
  File file = File("");
  String path = "";

  List<Circle> clist = [];
  bool deletepressed = false, savedrawing = false;
  double fontsize = 20;
  int frameRate = 60;
  bool changing = false,
      keepcircles = false,
      d = false,
      filledcircles = false,
      first_touch = false,
      draw = false,
      erasing = false,
      savebackup = false,
      loadbackup = false,
      isundo = false,
      isredo = false;
  String windowsdirectory = 'C:\\Users\\User\\Desktop\\';
  double radius = 1, maxsize = 0;
  Timer? animation;
  ui.Image? undoimg, redoimg;

  var bufferedPointerCount = 1;
  var bufferTolerance = 500; // in ms
  var pointerBufferTimer;

  final _keyCustomPaint = GlobalKey();
  Animation<double>? _animation;
  AnimationController? controller;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    super.initState();
    controller =
        AnimationController(duration: Duration(milliseconds: 400), vsync: this);

    controller?.forward();
    controller?.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller?.reset();
      } else if (status == AnimationStatus.dismissed) {
        controller?.forward();
      }
    });
    start_animation();
  }

  Widget buildcolorpicker(MyColor cl) {
    return Expanded(
      child: ColorPicker(
          labelTextStyle: TextStyle(color: uicolor.color),
          pickerColor: cl.color,
          onColorChanged: (color) {
            //setState(() {
            cl.color = color;
            //});
          }),
    );
  }

  Future<Uint8List> _capturePng() async {
    Uint8List pngBytes = Uint8List(0);
    try {
      RenderRepaintBoundary boundary = _keyCustomPaint.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = (await boundary.toImage(pixelRatio: 1.0));
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      pngBytes = byteData!.buffer.asUint8List();
    } on Exception catch (e) {
      //print(e.toString());
    }
    return pngBytes;
  }

  Future<ui.Image?> _savestep() async {
    ui.Image? image;
    try {
      RenderRepaintBoundary boundary = _keyCustomPaint.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;
      image = (await boundary.toImage(pixelRatio: 1.0));
    } on Exception catch (e) {
      //print(e.toString());
    }
    return image;
  }

  void start_animation() {
    if (dir == 1) {
      _animation = Tween(begin: radiusO, end: maxsize).animate(controller!)
        ..addListener(() {
          if (first_touch && speed < maxspeed - 1) {
            radius = _animation!.value;
          }
        });
    } else if (dir == 2) {
      _animation = Tween(begin: 0.0, end: radiusO).animate(controller!)
        ..addListener(() {
          if (first_touch && speed < maxspeed - 1) {
            radius = radiusO - _animation!.value;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (appheight != MediaQuery.of(context).size.height ||
        appwidth != MediaQuery.of(context).size.width) {
      setState(() {
        appheight = MediaQuery.of(context).size.height;
        appwidth = MediaQuery.of(context).size.width;
        if (appheight > appwidth) {
          maxsize = appheight;
        } else {
          maxsize = appwidth;
        }
        //maxsize /= 2;
      });
    }
    return Scaffold(
        body: Stack(
      children: [
        SizedBox(
          // size = constraints.biggest;
          // scale = MediaQuery.of(context).devicePixelRatio;
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: GestureDetector(
            onPanDown: (details) {
              X1 = details.localPosition.dx;
              Y1 = details.localPosition.dy;
              radius = radiusO;
              radprev = radius;
              XO = details.localPosition.dx;
              YO = details.localPosition.dy;
              //radiusO = radius;
              if (keepcircles) isredo = false;
              first_touch = true;
              draw = true;
              controller?.reset();
              controller?.forward();
              start_animation();
            },
            onPanUpdate: (details) {
              double nr = 0;
              if (first_touch) {
                nr = (details.localPosition.dx - XO) *
                    (details.localPosition.dx - XO);
                nr += (details.localPosition.dy - YO) *
                    (details.localPosition.dy - YO);
                if (sqrt(nr.toInt()) > 8) {
                  radius = radprev;
                  first_touch = false;
                }
              }
              if (!first_touch) {
                double X = details.localPosition.dx,
                    Y = details.localPosition.dy;

                XO = X1;
                YO = Y1;
                X1 = X;
                Y1 = Y;
                if (changing) {
                  // / clist.length; //3
                  if (dir == 1) {
                    radius += changingspeed;
                    if (maxsize - radius < 0) {
                      /*sketch.fill(color: backgroundcl.color);
                      sketch.stroke(color: backgroundcl.color);
                      sketch.circle(
                          center: Offset(X1, Y1),
                          diameter: 2 * (radius - c + 0.5));*/
                      radius = radiusO;
                    }
                  } else if (dir == 2) {
                    radius -= changingspeed;
                    if (radius <= 1) {
                      radius = radiusO;
                    }
                  }
                }
                if (clist.length < 8) clist.add(Circle(X1, Y1, radius));
              }
            },
            onPanEnd: (details) async {
              clist.clear();
              if (keepcircles) {
                undoimg = await _savestep();
                isundo = true;
              }
              first_touch = false;

              if (!keepcircles) {
                deletepressed = true;
              }

              radius = radiusO;
            },
            child: RepaintBoundary(
              key: _keyCustomPaint,
              child: Processing(
                  sketch: Sketch.simple(setup: (s) async {
                s.size(
                    width: appwidth.toInt() + 1, height: appheight.toInt() + 1);
                s.background(color: backgroundcl.color);
                sketch = s;
                frameRate = s.frameRate;
                controller?.duration = Duration(
                    milliseconds: (maxsize / frameRate * speed).toInt());
              }, draw: (s) async {
                // if (savebackup) {
                //   String path = 'assets/backupdraw.png';
                //   final File file = File(path);
                //   await s.loadPixels();
                //   s.save(file: file);
                //   await s.updatePixels();
                //   savebackup = false;
                // }
                // if (loadbackup) {
                //   Image backupimg = Image.asset('assets/backupdraw.png');
                //   ByteData bytelist = s.pixels!;
                //   int nr = 0;
                //   bytelist.getInt64(nr);
                //   loadbackup = false;
                // }

                if (deletepressed) {
                  deletepressed = false;
                  s.background(color: backgroundcl.color);
                }
                //if (ic1.icon == Icons.play_arrow) return;
                if (draw) {
                  if (erasing) {
                    s.fill(color: backgroundcl.color);
                    s.stroke(color: backgroundcl.color);
                    for (int i = 0; i < clist.length; i++) {
                      s.circle(
                          center: Offset(clist[i].X, clist[i].Y),
                          diameter: 2 * eraserradius);
                    }
                    clist.clear();
                    return;
                  }
                  s.strokeWeight(circleweight);

                  if (dir == 1) {
                    // if (maxsize - radius <= 10) {
                    //   s.fill(color: backgroundcl.color);
                    //   s.stroke(color: backgroundcl.color);
                    //   s.circle(center: Offset(X1, Y1), diameter: 2 * radprev);
                    //   radius = radiusO;
                    // }
                    if (circleweight == 0)
                      s.stroke(color: fillcl.color);
                    else
                      s.stroke(color: strokecl.color);
                    s.fill(color: fillcl.color);
                    //s.circle(center: Offset(X1, Y1), diameter: 2 * radius);
                    if (first_touch) {
                      s.stroke(color: strokecl.color);
                      s.fill(color: fillcl.color);
                      s.circle(center: Offset(X1, Y1), diameter: 2 * radius);
                    } else {
                      for (int i = 0; i < clist.length; i++) {
                        s.circle(
                            center: Offset(clist[i].X, clist[i].Y),
                            diameter: 2 * radius);
                      }
                    }
                    if (!first_touch) clist.clear();
                  } else {
                    if (first_touch) {
                      s.stroke(color: backgroundcl.color);
                      s.fill(color: backgroundcl.color);

                      s.circle(
                          center: Offset(X1, Y1),
                          diameter: 2 * (radprev + circleweight * 2));
                      if (circleweight > 0)
                        s.stroke(color: strokecl.color);
                      else
                        s.stroke(color: fillcl.color);
                      s.fill(color: fillcl.color);

                      s.circle(center: Offset(X1, Y1), diameter: 2 * radius);
                    } else {
                      for (int i = 0; i < clist.length; i++) {
                        double nr = 0.7;

                        if (changing) {
                          s.stroke(color: backgroundcl.color);
                          s.fill(color: backgroundcl.color);

                          s.circle(
                              center: Offset(clist[i].X, clist[i].Y),
                              diameter: 2 * (radprev + circleweight * 2));
                        }
                        if (circleweight > 0)
                          s.stroke(color: strokecl.color);
                        else
                          s.stroke(color: fillcl.color);
                        s.fill(color: fillcl.color);

                        s.circle(
                            center: Offset(clist[i].X, clist[i].Y),
                            diameter: 2 * radius);
                      }
                    }
                    if (!first_touch) clist.clear();
                    /*s.circle(
                    center: Offset(X1, Y1), diameter: 2 * (radius + c + 0.7));
                    s.stroke(color: strokecl.color);
                    s.fill(color: fillcl.color);
                    s.circle(center: Offset(X1, Y1), diameter: 2 * radius);*/
                  }
                  radprev = radius;
                }
                // if (savedrawing) {
                //   int timestamp = DateTime.now().millisecondsSinceEpoch;
                //   String filename =
                //       "FluidCircles_" + timestamp.toString() + ".png";
                //   await s.loadPixels();
                // if (Platform.isWindows) {
                //   final File file = File(windowsdirectory + filename);
                //   s.save(file: file);
                // } else if (Platform.isAndroid || Platform.isIOS) {
                //   var appDocDir = await getExternalStorageDirectory();
                //   path = '${appDocDir!.path}/$filename';
                //   file = File(path);
                //   s.save(file: file);
                //   await GallerySaver.saveImage(path);
                // }
                //   await s.updatePixels();
                //   savedrawing = false;
                // }
                //await s.loadPixels();
                //print(s.frameRate);
                //s.noLoop();
                //await s.updatePixels();
              })),
            ),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.adjust),
            color: Colors.white,
            onPressed: () {
              speed = maxspeed - speed + minspeed;

              clist.clear();
              showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black38,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return StatefulBuilder(builder: (BuildContext context,
                        StateSetter setState /*You can rename this!*/) {
                      return Center(
                        child: ListView(
                          children: <Widget>[
                            //space

                            Text(
                              'OPTIONS',
                              style: TextStyle(
                                  fontSize: fontsize * 2, color: uicolor.color),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(
                              height: 30,
                            ),

                            Text(
                              'SET THE START RADIUS: ${radiusO.toInt()}',
                              style: TextStyle(
                                  fontSize: fontsize, color: uicolor.color),
                              textAlign: TextAlign.center,
                            ),
                            Row(
                              children: [
                                Spacer(),
                                SizedBox(
                                  width: 300,
                                  child: Slider(
                                    activeColor: uicolor.color,
                                    value: radiusO,
                                    max: maxsize / 2 - 10,
                                    min: 1,
                                    label: radiusO.toInt().toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        radiusO = value;
                                        radius = radiusO;
                                      });
                                    },
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),
                            SizedBox(
                              height: 10,
                            ),

                            Row(
                              children: <Widget>[
                                Spacer(),
                                Checkbox(
                                  checkColor: Colors.black,
                                  activeColor: uicolor.color,
                                  side: BorderSide(color: uicolor.color),
                                  value: changing,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      changing = value as bool;
                                    });
                                  },
                                ),
                                Text(
                                  "CHANGE CIRCLE'S SIZE",
                                  style: new TextStyle(
                                    fontSize: fontsize,
                                    color: uicolor.color,
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            // //space
                            SizedBox(
                              height: 10,
                            ),

                            Row(
                              children: [
                                Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (dir == 1) {
                                        dir = 2;
                                        radiusO = maxsize / 2 - 10;
                                        radius = radiusO;
                                      } else {
                                        dir = 1;
                                        radiusO = 1;
                                        radius = 1;
                                      }
                                    });
                                  },
                                  child: Text(
                                    dir == 1
                                        ? 'DIRECTION OF THE CIRCLES:OUT'
                                        : 'DIRECTION OF THE CIRCLES:IN',
                                    style: new TextStyle(
                                      fontSize: fontsize,
                                      color: uicolor.color,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),
                            // //space
                            SizedBox(
                              height: 10,
                            ),

                            Row(
                              children: <Widget>[
                                Spacer(),
                                Checkbox(
                                  checkColor: Colors.black,
                                  activeColor: uicolor.color,
                                  side: BorderSide(color: uicolor.color),
                                  value: keepcircles,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      keepcircles = value as bool;
                                      if (!keepcircles) {
                                        isundo = false;
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  'KEEP CIRCLES',
                                  style: new TextStyle(
                                    fontSize: fontsize,
                                    color: uicolor.color,
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            SizedBox(
                              height: 10,
                            ),

                            if (keepcircles)
                              Row(
                                children: [
                                  Spacer(),
                                  IconButton(
                                    tooltip: "Undo",
                                    icon: Icon(Icons.undo_rounded,
                                        color: isundo
                                            ? uicolor.color
                                            : Color.fromARGB(78, 87, 82, 82)),
                                    onPressed: () async {
                                      if (isundo) {
                                        isundo = false;
                                        isredo = true;
                                        redoimg = await _savestep();
                                        try {
                                          ByteData? byteData =
                                              await undoimg?.toByteData(
                                                  format:
                                                      ui.ImageByteFormat.png);

                                          PImage pimg = PImage.fromPixels(
                                              undoimg!.width.toInt(),
                                              undoimg!.height.toInt(),
                                              byteData!,
                                              ImageFileFormat.png);
                                          Image? img = (await pimg
                                              .toFlutterImage()) as Image?;
                                          sketch.image(image: pimg);
                                        } on Exception catch (e) {
                                          //print(e.toString());
                                        }

                                        //???
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: "Redo",
                                    icon: Icon(Icons.redo_rounded,
                                        color: isredo
                                            ? uicolor.color
                                            : Color.fromARGB(78, 87, 82, 82)),
                                    onPressed: () {
                                      if (isredo) {
                                        setState(() async {
                                          isredo = false;
                                          isundo = true;
                                          undoimg = await _savestep();
                                          try {
                                            RenderRepaintBoundary boundary =
                                                _keyCustomPaint.currentContext
                                                        ?.findRenderObject()
                                                    as RenderRepaintBoundary;

                                            ByteData? byteData =
                                                await redoimg?.toByteData(
                                                    format:
                                                        ui.ImageByteFormat.png);
                                            ui.Codec codec =
                                                await ui.instantiateImageCodec(
                                                    await _capturePng());
                                            ui.FrameInfo frameInfo =
                                                await codec.getNextFrame();
                                            redoimg = frameInfo.image;
                                            PImage pimg = PImage.fromPixels(
                                                redoimg!.width.toInt(),
                                                redoimg!.height.toInt(),
                                                byteData!,
                                                ImageFileFormat.png);
                                            sketch.image(image: pimg);
                                          } on Exception catch (e) {
                                            //print(e.toString());
                                          }

                                          //???
                                          setState(() {});
                                          //???
                                        });
                                      }
                                    },
                                  ),
                                  Spacer(),
                                ],
                              ),

                            if (keepcircles)
                              Row(
                                children: [
                                  Spacer(),
                                  IconButton(
                                      onPressed: () {
                                        setState(() {
                                          erasing = !erasing;
                                        });
                                      },
                                      icon: Icon(
                                          erasing == false
                                              ? Icons.border_clear
                                              : Icons.draw,
                                          color: uicolor.color)),
                                  IconButton(
                                      onPressed: () {
                                        setState(() {
                                          deletepressed = true;
                                        });
                                      },
                                      icon: Icon(Icons.delete,
                                          color: uicolor.color)),
                                  Spacer(),
                                ],
                              ),

                            if (keepcircles)
                              Row(
                                children: [
                                  Spacer(),
                                  Text(
                                    'ERASER RADIUS:',
                                    style: TextStyle(
                                        fontSize: fontsize,
                                        color: uicolor.color),
                                  ),
                                  Spacer(),
                                ],
                              ),

                            if (keepcircles)
                              Row(
                                children: [
                                  Spacer(),
                                  SizedBox(
                                    width: 300,
                                    child: Slider(
                                      activeColor: uicolor.color,
                                      value: eraserradius,
                                      max: 100,
                                      min: 5,
                                      label: eraserradius.toString(),
                                      onChanged: (double value) {
                                        setState(() {
                                          eraserradius = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Spacer(),
                                ],
                              ),

                            SizedBox(
                              width: 10,
                            ),

                            Divider(
                              height: 10,
                              thickness: 2,
                              color: uicolor.color,
                            ),

                            Text(
                              'SELECT COLOR:',
                              style: TextStyle(
                                  fontSize: 4 / 3 * fontsize,
                                  color: uicolor.color),
                              textAlign: TextAlign.center,
                            ),
                            Row(children: [
                              Spacer(),
                              Text(
                                'BACKGROUND COLOR:',
                                style: TextStyle(
                                    fontSize: fontsize, color: uicolor.color),
                              ),
                              IconButton(
                                  onPressed: () {
                                    MyColor cl = MyColor(backgroundcl.color);
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                              titleTextStyle:
                                                  TextStyle(color: Colors.blue),
                                              backgroundColor: Color.fromARGB(
                                                  125, 29, 29, 29),
                                              title: Text(
                                                'BACKGROUND COLOR:',
                                                style: TextStyle(fontSize: 20),
                                              ),
                                              content:
                                                  Column(children: <Widget>[
                                                buildcolorpicker(cl),
                                                TextButton(
                                                  child: Text('SELECT',
                                                      style: TextStyle(
                                                          fontSize: fontsize,
                                                          color:
                                                              uicolor.color)),
                                                  onPressed: () {
                                                    setState(() {
                                                      backgroundcl.color =
                                                          cl.color;
                                                      deletepressed = true;
                                                      Navigator.of(context)
                                                          .pop();
                                                    });
                                                  },
                                                ),
                                              ]),
                                            ));
                                  },
                                  icon: Icon(
                                    Icons.color_lens,
                                    color: uicolor.color,
                                  )),
                              SizedBox(width: 20),
                              CircleAvatar(
                                backgroundColor: backgroundcl.color,
                              ),
                              Spacer(),
                            ]),

                            Row(children: [
                              Spacer(),
                              Text(
                                'STROKE COLOR:',
                                style: TextStyle(
                                    fontSize: fontsize, color: uicolor.color),
                              ),
                              IconButton(
                                  onPressed: () {
                                    MyColor cl = MyColor(strokecl.color);
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                              titleTextStyle:
                                                  TextStyle(color: Colors.blue),
                                              backgroundColor: Color.fromARGB(
                                                  125, 29, 29, 29),
                                              title: Text(
                                                'STROKE COLOR:',
                                                style: TextStyle(fontSize: 20),
                                              ),
                                              content:
                                                  Column(children: <Widget>[
                                                buildcolorpicker(cl),
                                                TextButton(
                                                  child: Text('SELECT',
                                                      style: TextStyle(
                                                          fontSize: fontsize,
                                                          color:
                                                              uicolor.color)),
                                                  onPressed: () {
                                                    setState(() {
                                                      strokecl.color = cl.color;
                                                      Navigator.of(context)
                                                          .pop();
                                                    });
                                                  },
                                                ),
                                              ]),
                                            ));
                                  },
                                  icon: Icon(
                                    Icons.color_lens,
                                    color: uicolor.color,
                                  )),
                              SizedBox(width: 20),
                              CircleAvatar(
                                backgroundColor: strokecl.color,
                              ),
                              IconButton(
                                  tooltip: "Copy background color",
                                  onPressed: () {
                                    setState(() {
                                      strokecl.color = backgroundcl.color;
                                    });
                                  },
                                  icon:
                                      Icon(Icons.delete, color: uicolor.color)),
                              IconButton(
                                  tooltip: "Copy fill color",
                                  onPressed: () {
                                    setState(() {
                                      strokecl.color = fillcl.color;
                                    });
                                  },
                                  icon: Icon(Icons.copy_all_rounded,
                                      color: uicolor.color)),
                              Spacer(),
                            ]),

                            Row(children: [
                              Spacer(),
                              Text(
                                'FILL COLOR:',
                                style: TextStyle(
                                    fontSize: fontsize, color: uicolor.color),
                              ),
                              IconButton(
                                  onPressed: () {
                                    MyColor cl = MyColor(fillcl.color);
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                              titleTextStyle:
                                                  TextStyle(color: Colors.blue),
                                              backgroundColor: Color.fromARGB(
                                                  125, 29, 29, 29),
                                              title: Text(
                                                'FILL COLOR:',
                                                style: TextStyle(fontSize: 20),
                                              ),
                                              content:
                                                  Column(children: <Widget>[
                                                buildcolorpicker(cl),
                                                TextButton(
                                                  child: Text('SELECT',
                                                      style: TextStyle(
                                                          fontSize: fontsize,
                                                          color:
                                                              uicolor.color)),
                                                  onPressed: () {
                                                    setState(() {
                                                      fillcl.color = cl.color;
                                                      Navigator.of(context)
                                                          .pop();
                                                    });
                                                  },
                                                ),
                                              ]),
                                            ));
                                  },
                                  icon: Icon(
                                    Icons.color_lens,
                                    color: uicolor.color,
                                  )),
                              SizedBox(width: 20),
                              CircleAvatar(
                                backgroundColor: fillcl.color,
                              ),
                              IconButton(
                                  tooltip: "Copy background color",
                                  onPressed: () {
                                    setState(() {
                                      fillcl.color = backgroundcl.color;
                                    });
                                  },
                                  icon:
                                      Icon(Icons.delete, color: uicolor.color)),
                              IconButton(
                                  tooltip: "Copy stroke color",
                                  onPressed: () {
                                    setState(() {
                                      fillcl.color = strokecl.color;
                                    });
                                  },
                                  icon: Icon(Icons.copy_all_rounded,
                                      color: uicolor.color)),
                              Spacer(),
                            ]),

                            Divider(
                              height: 10,
                              thickness: 2,
                              color: uicolor.color,
                            ),

                            SizedBox(
                              width: 10,
                            ),

                            Row(
                              children: [
                                Spacer(),
                                Text(
                                  'SPEED:',
                                  style: TextStyle(
                                      fontSize: fontsize, color: uicolor.color),
                                ),
                                Spacer(),
                              ],
                            ),

                            Row(
                              children: [
                                Spacer(),
                                SizedBox(
                                  width: 240,
                                  child: Slider(
                                    activeColor: uicolor.color,
                                    value: speed,
                                    max: maxspeed - 1,
                                    min: minspeed + 1,
                                    label: speed.toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        speed = value;
                                      });
                                    },
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            SizedBox(
                              width: 10,
                            ),

                            Row(
                              children: [
                                Spacer(),
                                Text(
                                  'THICKNESS:',
                                  style: TextStyle(
                                      fontSize: fontsize, color: uicolor.color),
                                ),
                                Spacer(),
                              ],
                            ),

                            Row(
                              children: [
                                Spacer(),
                                SizedBox(
                                  width: 300,
                                  child: Slider(
                                    activeColor: uicolor.color,
                                    value: circleweight,
                                    max: 60,
                                    min: 0,
                                    label: circleweight.toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        circleweight = value;
                                      });
                                    },
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            SizedBox(
                              width: 10,
                            ),

                            SizedBox(
                              width: 30,
                            ),

                            Row(
                              children: [
                                Spacer(),
                                TextButton(
                                  child: new Text(
                                    " OK ",
                                    style: new TextStyle(
                                      fontSize: 4 / 3 * fontsize,
                                      color: uicolor.color,
                                    ),
                                  ),
                                  onPressed: () {
                                    changingspeed = speed > minspeed + 1
                                        ? (speed - minspeed) / 100
                                        : 0;
                                    double c =
                                        speed = maxspeed - speed + minspeed;
                                    controller?.duration = Duration(
                                        milliseconds:
                                            (maxsize / frameRate * speed)
                                                .toInt());
                                    Navigator.pop(context);
                                  },
                                ),
                                Spacer(),
                              ],
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            IconButton(
                                onPressed: () async {
                                  savedrawing = true;
                                  int timestamp =
                                      DateTime.now().millisecondsSinceEpoch;
                                  String filename = "FLUIDCIRCLES_" +
                                      timestamp.toString() +
                                      ".png";
                                  final Uint8List bytes = await _capturePng();
                                  if (Platform.isWindows) {
                                    File file =
                                        File('$windowsdirectory\\$filename');
                                    await file.writeAsBytes(bytes);
                                  } else if (Platform.isAndroid ||
                                      Platform.isIOS) {
                                    var appDocDir =
                                        await getExternalStorageDirectory();
                                    path = '${appDocDir!.path}/$filename';
                                    file = File(path);
                                    await file.writeAsBytes(bytes);
                                    await GallerySaver.saveImage(path);
                                  }
                                },
                                icon:
                                    Icon(Icons.save_alt, color: uicolor.color)),

                            SizedBox(height: 10),

                            /*Row(
                              children: [
                                Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    int timestamp =
                                        DateTime.now().millisecondsSinceEpoch;
                                    TextEditingController tcnt =
                                        TextEditingController(
                                            text: timestamp.toString());
                                    savebackup = true;
                                    showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            content: TextField(
                                              cursorColor: Colors.black87,
                                              controller: tcnt,
                                              decoration: InputDecoration(
                                                  hintStyle: TextStyle(
                                                      color: Colors.black87),
                                                  hintText: "Enter your text"),
                                            ),
                                            actions: [
                                              FlatButton(
                                                // FlatButton widget is used to make a text to work like a button
                                                textColor: Colors.black,
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  loadbackup = true;
                                                }, // function used to perform after pressing the button
                                                child: Text('CANCEL'),
                                              ),
                                              FlatButton(
                                                textColor: Colors.black,
                                                onPressed: () {},
                                                child: Text('ACCEPT'),
                                              ),
                                            ],
                                          );
                                        });

                                    /* String filename = "FluidCircles_" +
                                        timestamp.toString() +
                                        ".json";
                                    if (Platform.isWindows) {
                                      File file =
                                          File('$windowsdirectory\\$filename');
                                    } else if (Platform.isAndroid ||
                                        Platform.isIOS) {
                                      var appDocDir =
                                          await getExternalStorageDirectory();
                                      path =
                                          '${appDocDir!.path}/$filename';
                                      file = File(path);
                                    }
                                    final state = [
                                      {"typem": _currtypemval},
                                      {"typec": _currtypecval},
                                      {"x0": _currxval._val},
                                      {"y0": _curryval._val},
                                      {"miu": _currmiuval._val},
                                      {"alpha": _curralphaval._val},
                                      {"iter": _curriterval._val},
                                      {"sigma": _currsigmaval._val},
                                      {"xorig": _xOrig},
                                      {"yorig": _yOrig},
                                      {"xscaling": _xScaling},
                                      {"yscaling": _yScaling},
                                      {"colors": _colList},
                                      {"checked": _isChecked}
                                    ];
                                    await file
                                        .writeAsString(json.encode(state));
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text("Information"),
                                          content: Text(filename + " saved!"),
                                          actions: [
                                            TextButton(
                                              child: const Text("OK"),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    */
                                  },
                                  child: Text(
                                    "SAVE PARAMETERS",
                                    style: new TextStyle(
                                      fontSize: fontsize,
                                      color: uicolor.color,
                                    ),
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),

                            SizedBox(
                              width: 10,
                            ),*/

                            //space

                            Row(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      showAboutDialog(
                                        context: context,
                                        applicationName: "Fluid Circles",
                                        applicationLegalese:
                                            "© 2022 Nicolae Luca. All rights reserved.",
                                      );
                                    },
                                    icon: Icon(Icons.info_outline_rounded,
                                        color: uicolor.color)),
                                Spacer(),
                                FloatingActionButton(
                                  onPressed: () {
                                    MyColor cl = MyColor(uicolor.color);
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                              titleTextStyle: TextStyle(
                                                  color: uicolor.color),
                                              backgroundColor: Color.fromARGB(
                                                  125, 29, 29, 29),
                                              title: Text(
                                                'SELECT UI COLOR',
                                                style: TextStyle(
                                                    fontSize: fontsize),
                                              ),
                                              content:
                                                  Column(children: <Widget>[
                                                buildcolorpicker(cl),
                                                TextButton(
                                                  child: Text('SELECT',
                                                      style: TextStyle(
                                                          fontSize: fontsize,
                                                          color:
                                                              uicolor.color)),
                                                  onPressed: () {
                                                    setState(() {
                                                      uicolor.color = cl.color;
                                                      Navigator.of(context)
                                                          .pop();
                                                    });
                                                  },
                                                ),
                                              ]),
                                            ));
                                  },
                                  child: Icon(
                                    Icons.colorize_rounded,
                                    color: uicolor.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    });
                  });
            }),
      ],
    ));
  }
}
