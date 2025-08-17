import 'dart:io'; // Required for File operations
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skeche',
      darkTheme: ThemeData.dark(),
      home: const GalleryAccess(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GalleryAccess extends StatefulWidget {
  const GalleryAccess({super.key});


  @override
  State<GalleryAccess> createState() => _GalleryAccessState();
}


class _GalleryAccessState extends State<GalleryAccess> {
  File? galleryFile;

  final picker = ImagePicker();
  
  Future getImage(ImageSource img,) async {
    // pick image from gallery
    final pickedFile = await picker.pickImage(source: img);
    // store it in a valid variable
    XFile? xfilePick = pickedFile;
    setState(() {
        if (xfilePick != null) {
          // store that in global variable galleryFile in the form of File
          galleryFile = File(pickedFile!.path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(// is this context <<<
            const SnackBar(content: Text('Nothing is selected')));
        }
      },
    );
  }

  void _pickImage({required BuildContext context}) {

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                getImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                getImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        );
      },
    );
  }

  // Here we apply the sketch
  Future<void> sketchEffect() async {
    if (galleryFile == null) return;

    // 1. Load image into opencv
    final src = cv.imread(galleryFile!.path);

    // 2. Convert to grayscale
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    // 3. Invert image - see if you need it or not
    final inverted = cv.bitwiseNOT(gray);

    // .4 Blur the inverted image
    final blur = cv.gaussianBlur(inverted, (21, 21), 0);

    // 5. invert the blured image
    final invertedBlur = cv.bitwiseNOT(blur);

    // 6. Create sketch by dividing gray by invertedBlur
    final sketch = cv.divide(gray, invertedBlur, scale: 256);

    // 7. Save result to temp file
    final outPath = '${galleryFile!.parent.path}/sketch.png';
    cv.imwrite(outPath, sketch);

    setState(() {
      galleryFile = File(outPath);
      });
  }

  // Here we display Widgets + add logic to them
  @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gallery Access and Camera'),
          backgroundColor: const Color.fromARGB(221, 13, 13, 13),
          foregroundColor: Colors.white,
        ),
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                    child: const Text('Select Image from Gallery or Camera'),
                    onPressed:() {
                      _pickImage(context: context);
                    const SizedBox(height: 4, width: 10);
                    },
                  ),

                  // The position of the button('Select Image')

                  // Size of the selected image
                  SizedBox(  
                    height: 738,
                    width: 500.0,
                    child: galleryFile == null
                        ? const Center(child: Text('Sorry nothing selected!!'))
                        : Center(child: Image.file(galleryFile!)),
                  ),
                  ElevatedButton(
                    onPressed: sketchEffect, 
                    child: const Text("Apply Sketch Effect"),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
}