import 'dart:typed_data';

import 'package:drawing_app/drawing_page.dart';
import 'package:drawing_app/collab_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:drawing_app/collab_loading_page.dart';

class MenuPage extends StatefulWidget {
  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  GlobalKey _globalKey = new GlobalKey();
  String appDirectory;
  List paintingFiles = [];
  List<Image> paintingPictures = [];
  TextEditingController _nameSelectorController;
  TextEditingController _heightSelectorController;
  TextEditingController _widthSelectorController;

  @override
  void initState() {
    super.initState();
    _listofFiles();
    _nameSelectorController = TextEditingController(text: '');
    _heightSelectorController = TextEditingController(text: '');
    _widthSelectorController = TextEditingController(text: '');
  }

  void resetMenu() {
    _listofFiles();
    _nameSelectorController = TextEditingController(text: '');
    _heightSelectorController = TextEditingController(text: '');
    _widthSelectorController = TextEditingController(text: '');
  }

  Future<Image> loadImage(folderPath) async {
    final String path = folderPath;
    final imageFile = File('$folderPath/thumbnail.png');
    final imageContents = await imageFile.readAsBytes();
    final image = Image.memory(Uint8List.fromList(imageContents));
    return image;
  }

  void _listofFiles() async {
    var dir = (await getApplicationDocumentsDirectory()).path;
    var files = Directory("$dir/paintings/").listSync();
    files.sort((a,b) => b.toString().compareTo(a.toString()));
    for (var j in files){
      print(j.path.split("/").last);
    }
    List<Image> pictures = [];
    for (var i in files) {
      final image = await loadImage(i.path);
      pictures.add(image);
    }
    setState(() {
      appDirectory = dir;
      paintingFiles = files;
      paintingPictures = pictures;
    });
  }

  void changeName(uuid, newName) async {
    var dir = (await getApplicationDocumentsDirectory()).path;
    var directory = Directory("$dir/paintings/$uuid");
    final newUuid = uuid.split("@")[0] + "@" + newName;
    directory.renameSync("$dir/paintings/$newUuid");
    resetMenu();
  }

  void deletePainting(uuid) async {
    var dir = (await getApplicationDocumentsDirectory()).path;
    var directory = Directory("$dir/paintings/$uuid");
    await directory.delete(recursive: true);
    resetMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGrey5,
      body: Stack(
        children: [
          Center(
            child: Swiper(
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return createNewDrawing();
                } else {
                  return loadExistingDrawing(paintingFiles[index-1].path.split("/").last, paintingPictures[index-1], paintingFiles[index-1].path.split("/").last.split("@")[1]);
                }
              },
              itemCount: paintingFiles.length + 1,
              pagination: SwiperPagination(
                  margin: EdgeInsets.only(bottom: 30)
              ),
              loop: false,
              layout: SwiperLayout.DEFAULT,
              viewportFraction: 0.4,
            ),
          ),
          buildExitBar(context),
        ],
      )
    );
  }

  void goToNewDrawing(name, height, width) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DrawingPage(name: name, mmCanvasHeight: height, mmCanvasWidth: width,))
    ).then((_) => resetMenu());
  }

  void goToExistingDrawing(uuid) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DrawingPage(inputUuid: uuid))
    ).then((_) => resetMenu());
  }

  void goToLiveDrawing() {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CollabLoadingPage())
    ).then((_) => resetMenu());
  }

  Widget createNewDrawing() {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 400,
            height: 30,
          ),
          GestureDetector(
            onTapUp: (_){
              return showDialog<bool>(
                context: context,
                builder: (context) {
                  return CupertinoAlertDialog(
                    title: Text('Create new drawing'),
                    content: Container(
                      margin: EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text("Name"),
                          CupertinoTextField(
                            controller: _nameSelectorController,
                          ),
                          Divider(
                            height: 20.0,
                          ),
                          Text("Height (mm)"),
                          CupertinoTextField(
                            controller: _heightSelectorController,
                          ),
                          Divider(
                            height: 20.0,
                          ),
                          Text("Width (mm)"),
                          CupertinoTextField(
                            controller: _widthSelectorController,
                          ),
                        ],
                      ),
                    ),
                    actions: <CupertinoDialogAction>[
                      CupertinoDialogAction(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      CupertinoDialogAction(
                        child: const Text('Create'),
                        isDefaultAction: true,
                        onPressed: () {
                          Navigator.pop(context);
                          goToNewDrawing(
                              _nameSelectorController.value.text,
                              double.parse(_heightSelectorController.value.text),
                              double.parse(_widthSelectorController.value.text),
                          );
                        },
                      )
                    ],
                  );
                },
              );
            },
            child: Card(
              child: Container(
                height: 300,
                width: 424,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      size: 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                "New Drawing",
                style: TextStyle(
                  fontSize: 20
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget loadExistingDrawing(paintingUuid, paintingPicture, paintingName) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 400,
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTapUp: (_){
                    return showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return CupertinoAlertDialog(
                          title: Text('Delete?'),
                          actions: <CupertinoDialogAction>[
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              isDefaultAction: true,
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                            CupertinoDialogAction(
                              child: const Text('Delete'),
                              isDestructiveAction: true,
                              onPressed: () {
                                Navigator.pop(context);
                                deletePainting(paintingUuid);
                              },
                            )
                          ],
                        );
                      },
                    );
                  },
                  child: Icon(
                    Icons.close,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTapUp: (_){
              goToExistingDrawing(paintingUuid);
            },
            child: Card(
              child: Container(
                height: 300,
                width: 424,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 300,
                      width: 424,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: paintingPicture.image,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onLongPress: () {
              _nameSelectorController = TextEditingController(text: paintingName);
              return showDialog<bool>(
                context: context,
                builder: (context) {
                  return CupertinoAlertDialog(
                    title: Text('Enter drawing name'),
                    content: Container(
                      margin: EdgeInsets.only(top: 10),
                      child: Column(
                        children: <Widget>[
                          CupertinoTextField(
                            controller: _nameSelectorController,
                          ),
                        ],
                      ),
                    ),
                    actions: <CupertinoDialogAction>[
                      CupertinoDialogAction(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      CupertinoDialogAction(
                        child: const Text('Rename'),
                        isDefaultAction: true,
                        onPressed: () {
                          Navigator.pop(context);
                          changeName(paintingUuid, _nameSelectorController.value.text);
                        },
                      )
                    ],
                  );
                },
              );
            },
            child: Container(
              margin: EdgeInsets.only(top: 20),
              child: Center(
                child: Text(
                  "$paintingName",
                  style: TextStyle(
                      fontSize: 20
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget buildExitBar(context) {
    return Builder(builder: (context) {
      return Positioned(
        top: 40.0,
        left: 20.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  buildLiveButton(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget buildLiveButton() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        goToLiveDrawing();
      },
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.blue),
        ),
        child: Row(
          children: [
            Text(
                "Go live!",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
            ),
            VerticalDivider(
              width: 10.0,
            ),
            Icon(
              Icons.stream,
              size: 20.0,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}