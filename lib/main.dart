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
  File? workingFile;        // always overwritten

  bool sketchEffect = false; // applies so the showsketch will work  
  bool showSketch = false;  // toggle between them

  final picker = ImagePicker();

  double _blurValue = 21;   // detail level (lernel size)
  double _scaleValue = 256; // intensity of division

  double _brightnessValue = 0; // range: -100 to +100
  double _contrastValue = 1.0; // range: 0.5 to 3.0

  // indicate processing so UI can show loader
  bool _isProcessing = false;

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

      // Clear any previous working result
      if (workingFile != null) {
        try {
          if (await workingFile!.exists()) await workingFile!.delete();
        } catch (_) {}
        workingFile = null;
      }

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

 Future<void> applyAdjustments() async {
  if (originalFile == null) return;

  setState(() {
    _isProcessing = true;
  });

  // let the UI update before heavy work
  await Future.delayed(Duration(milliseconds: 50));

  try{
    // Remove previous working file if present 
    if (workingFile != null) {
      try {
        if (await workingFile!.exists()) await workingFile!.delete();
      } catch (_) {}
      workingFile = null;
    }

    // Read from tje saved original copy
    final src = cv.imread(originalFile!.path);

    // 1) Apply brightness + contrast first to the original image
    //    so these changes affect the image BEFORE the sketch pipeline.
    var processed = cv.convertScaleAbs(src, alpha: _contrastValue, beta: _brightnessValue);

    // 2) If sketch effect is enabled -> produce sketch from the processed image
    //    (use detail/blur and intensity/scale values). This ensures brightness/contrast
    //    were applied to the input of the sketch, not to the sketch result.
    if (sketchEffect) {
      // Convert the brightness/contrast result to grayscale
      final gray = cv.cvtColor(processed, cv.COLOR_BGR2GRAY);

      // Invert the grayscale
      final inverted = cv.bitwiseNOT(gray);

      // Blur the inverted image (detail controlled by _blurValue)
      final blur = cv.gaussianBlur(inverted, (_blurValue.toInt(), _blurValue.toInt()), 0);

      // Invert the blurred image
      final invertedBlur = cv.bitwiseNOT(blur);

      // Create sketch by dividing the gray by invertedBlur using _scaleValue (intensity)
      processed = cv.divide(gray, invertedBlur, scale: _scaleValue);
    }

    // 3) Write result to a working file (overwrites the previous file name)
    final outPath = '${originalFile!.parent.path}/working_${DateTime.now().millisecondsSinceEpoch}.png';
    cv.imwrite(outPath, processed);

    setState(() {
      workingFile = File(outPath); // show new processed copy
      showSketch = true;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('processing failed: $e')),
    );
  } finally {
    setState(() {
      _isProcessing = false;
    });
  }
}

  // Here we display Widgets + add logic to them
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
                    height: 300,
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
                              showSketch  ? (workingFile ?? originalFile!) : originalFile!,
                            ),
                          ),
                  ),

                  // Detail scroll bar
                  Slider(
                    value: _blurValue,    // current slider posotion (must be double)
                    min: 1,
                    max: 51,
                    divisions: 25,        // number of steps between min and max
                    label: "Detail: ${_blurValue.toInt()}",
                    onChanged: (val) {
                      setState(() => _blurValue = val);
                    },
                  ),

                  // Intensity scroll bar
                  Slider(
                    value: _scaleValue,             // current slider position (must be double)
                    min: 50,
                    max: 500,
                    divisions: 45,                  //number of steps between min and max
                    label: "Intensity: ${_scaleValue.toInt()}",
                    onChanged: (val) {
                      setState(() => _scaleValue = val); // update the state with new value
                    },
                  ),

                  
                  // Brightness
                  Slider(
                    value: _brightnessValue,
                    min: -100,
                    max: 100,
                    divisions: 200,
                    label: "Brightness ${_brightnessValue.toInt()}",
                    onChanged: (val) {
                      setState(() => _brightnessValue = val);
                    },
                  ),

                  // Contrast
                  Slider(
                    value: _contrastValue,
                    min: 0.5,
                    max: 3.0,
                    divisions: 50,
                    label: "Contrast: ${_contrastValue.toStringAsFixed(2)}",
                    onChanged: (val) {
                      setState(() => _contrastValue = val);
                    },
                  ),

                    // button: click to apply all the changes
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 40), // width: 160, height: 40
                    ),
                    onPressed: _isProcessing ? null : () async {
                      await applyAdjustments();
                    },
                    child: const Text("Apply Changes"),
                  ),

                  // Apply the sketch effect (toggle only: user must press Apply Changes)
                  ElevatedButton(
                    onPressed:() {
                      setState(() {
                        sketchEffect = !sketchEffect;
                      });
                    },
                    child: Text(sketchEffect ? "Sketch: ON" : "Sketch: OFF"),
                  ),
                  
                  // This button switches between the original image and the image that has the sketch effect applied
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showSketch = !showSketch;
                      });
                    },
                    child: Text(showSketch ? "Show Original" : "Show Sketch"), 
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
}