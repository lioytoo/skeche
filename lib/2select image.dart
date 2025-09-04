import 'dart:io'; // Required for File operations
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(context) {
    return MaterialApp(
      title: 'Skeche',
      home: const GalleryAccess(),
      theme: ThemeData(),

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
  File? originalFile;       // original

    final picker = ImagePicker();


  Future getImage(ImageSource img,) async {
    // pick image from gallery
    final pickedFile = await picker.pickImage(source: img);
    if (pickedFile == null) return;

    try {
      // copy the picked file to create a stable "original" copy we can reuse
      final srcFile = File(pickedFile.path);
      final ext = pickedFile.path.contains('.') ? '.${pickedFile.path.split('.').last}' : '.png';
      final copyPath =
        '${srcFile.parent.path}/original_${DateTime.now().millisecondsSinceEpoch}$ext';
      originalFile = await srcFile.copy(copyPath);


      setState(() {});
    } catch (e) {
      // keep it simple: notify user and don't crash
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get Image: $e')),
      );
    }
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
  @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 42, 45, 50),
        appBar: AppBar(
          title: const Text('Gallery Access and Camera'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // First Select Image
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 40), //width: 250, height: 40
                    ),
                    child: const Text('Select Image from Gallery or Camera'),
                    onPressed:() {
                      _pickImage(context: context);
                    },
                  ),

                  // Size of the selected image
                  SizedBox(
                    height: 750,
                    width: 500.0,
                    child: originalFile == null
                        ? const Center(child: Text('Sorry nothing selected!!',
                            style: TextStyle(color: Colors.white),
                            ),
                          )
                        : Center(
                            child: Image.file(
                              // Show working copy only when showSketch is true,
                              // otherwise show the original. If workingFile is null
                              // fall back to original.
                              originalFile!
                            ),
                          ),
                        )
                      ],
              ),
            );
          },
        ),
      );
    }
}