import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Model Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ARModelViewer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ARModelViewer extends StatefulWidget {
  const ARModelViewer({Key? key}) : super(key: key);

  @override
  State<ARModelViewer> createState() => _ARModelViewerState();
}

class _ARModelViewerState extends State<ARModelViewer> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  List<ARNode> nodes = [];
  String? modelPath;
  bool isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Model Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearModels,
            tooltip: 'Limpiar modelos',
          ),
        ],
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadGLBModel,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Cargar GLB'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isModelLoaded ? _placeModel : null,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Colocar Modelo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isModelLoaded)
            const Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Carga un modelo GLB para comenzar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager,
      ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
    );

    this.arObjectManager!.onInitialize();
    this.arSessionManager!.onPlaneOrPointTap = _handleOnPlaneTap;
  }

  Future<void> _loadGLBModel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          modelPath = result.files.single.path!;
          isModelLoaded = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modelo cargado: ${result.files.single.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar modelo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleOnPlaneTap(List<ARHitTestResult> hitTestResults) async {
    if (!isModelLoaded || modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero carga un modelo GLB'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    var singleHitTestResult = hitTestResults.firstWhere(
          (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
    );

    await _addModel(singleHitTestResult);
  }

  Future<void> _placeModel() async {
    if (!isModelLoaded || modelPath == null) return;

    // Colocar el modelo en el centro de la vista
    var newNode = ARNode(
      type: NodeType.localGLTF2,
      uri: modelPath!,
      scale: vector.Vector3(0.2, 0.2, 0.2),
      position: vector.Vector3(0.0, 0.0, -1.0),
      rotation: vector.Vector4(1, 0, 0, 0),
    );

    bool? didAddNode = await arObjectManager!.addNode(newNode);
    if (didAddNode == true) {
      nodes.add(newNode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modelo colocado en la escena'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addModel(ARHitTestResult hitTestResult) async {
    var newAnchor = ARPlaneAnchor(transformation: hitTestResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      var newNode = ARNode(
        type: NodeType.localGLTF2,
        uri: modelPath!,
        scale: vector.Vector3(0.2, 0.2, 0.2),
        position: hitTestResult.worldTransform.getTranslation(),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      bool? didAddNode = await arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
      if (didAddNode == true) {
        nodes.add(newNode);
      }
    }
  }

  void _clearModels() {
    for (var node in nodes) {
      arObjectManager!.removeNode(node);
    }
    nodes.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modelos eliminados'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}