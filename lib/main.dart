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


  Future getImage(ImageSource img,) async {
    // pick image from gallery
    final pickedFile = await picker.pickImage(source: img);
    // store it in a valid variable
    XFile? xfilePick = pickedFile;
    setState(() {
        if (xfilePick != null) {
          // store that in global variable galleryFile in the form of File
          originalFile = File(pickedFile!.path);
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

 Future<void> applyAdjustments() async {
  if (originalFile == null) return;

  // Delete previous working file if it exists
  if (workingFile != null && await workingFile!.exists()) {
    await workingFile!.delete();
  }

  // Always start from original
  final src = cv.imread(originalFile!.path);

  // Apply brightness + contrast
  var proccessed = cv.convertScaleAbs(src, alpha: _contrastValue, beta: _brightnessValue);

  // Optionally apply sketch
  if (sketchEffect) {
    // 2. Convert to grayscale
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    // 3. Invert image - see if you need it or not
    final inverted = cv.bitwiseNOT(gray);

    // .4 Blur the inverted image
    final blur = cv.gaussianBlur(inverted, (_blurValue.toInt(), _blurValue.toInt()), 0);

    // 5. invert the blured image
    final invertedBlur = cv.bitwiseNOT(blur);

    // 6. Create sketch by dividing gray by invertedBlur
    proccessed = cv.divide(gray, invertedBlur, scale: _scaleValue);
  }

  // 7. Save adjusted image to file
  final outPath = '${originalFile!.parent.path}/working.png';
  cv.imwrite(outPath, proccessed);

  setState(() {
    workingFile = File(outPath); // Keep result in working copy so original stays as it is
  });
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
                              workingFile != null ? workingFile! : originalFile!,
                            ),
                          ),
                  ),

                  // Detail scroll bar - no logic yet
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
                    onPressed: applyAdjustments,
                    child: const Text("Apply"),
                  ),

                  // Apply the sketch effect
                  ElevatedButton(
                    onPressed:() {
                      setState(() {
                        sketchEffect = !sketchEffect;
                        applyAdjustments;
                      });
                    }, 
                    
                    child: const Text("Apply Sketch Effect"),
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