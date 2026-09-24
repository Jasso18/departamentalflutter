import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galería Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// --- MODELOS ---
class GalleryItem {
  final String id;
  String path;
  final DateTime dateAdded;
  bool isFavorite;
  bool isDeleted;
  String? folderId;

  GalleryItem({required this.id, required this.path, required this.dateAdded, this.isFavorite = false, this.isDeleted = false, this.folderId});
  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'dateAdded': dateAdded.toIso8601String(), 'isFavorite': isFavorite, 'isDeleted': isDeleted, 'folderId': folderId};
  factory GalleryItem.fromJson(Map<String, dynamic> json) => GalleryItem(id: json['id'], path: json['path'], dateAdded: DateTime.parse(json['dateAdded']), isFavorite: json['isFavorite'] ?? false, isDeleted: json['isDeleted'] ?? false, folderId: json['folderId']);
}

class GalleryFolder {
  final String id;
  String name;
  GalleryFolder({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory GalleryFolder.fromJson(Map<String, dynamic> json) => GalleryFolder(id: json['id'], name: json['name']);
}

// --- PROVIDER (ESTADO Y PERSISTENCIA) ---
class GalleryProvider with ChangeNotifier {
  List<GalleryItem> _items = [];
  List<GalleryFolder> _folders = [];
  final _uuid = const Uuid();

  GalleryProvider() { _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsString = prefs.getString('gallery_items');
    final foldersString = prefs.getString('gallery_folders');
    if (itemsString != null) _items = (jsonDecode(itemsString) as List).map((e) => GalleryItem.fromJson(e)).toList();
    if (foldersString != null) _folders = (jsonDecode(foldersString) as List).map((e) => GalleryFolder.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gallery_items', jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setString('gallery_folders', jsonEncode(_folders.map((e) => e.toJson()).toList()));
  }

  List<GalleryItem> get allItems => _items.where((item) => !item.isDeleted).toList();
  List<GalleryItem> get favoriteItems => _items.where((item) => item.isFavorite && !item.isDeleted).toList();
  List<GalleryItem> get deletedItems => _items.where((item) => item.isDeleted).toList();
  List<GalleryFolder> get folders => [..._folders];
  List<GalleryItem> getItemsInFolder(String folderId) => _items.where((item) => item.folderId == folderId && !item.isDeleted).toList();

  Future<void> addImages(List<String> paths) async {
    final appDir = await getApplicationDocumentsDirectory();
    for (var originalPath in paths) {
      final file = File(originalPath);
      final newPath = '${appDir.path}/${_uuid.v4()}.${originalPath.split('.').last}';
      await file.copy(newPath);
      _items.add(GalleryItem(id: _uuid.v4(), path: newPath, dateAdded: DateTime.now()));
    }
    await _saveData();
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) { _items[idx].isFavorite = !_items[idx].isFavorite; _saveData(); notifyListeners(); }
  }

  void moveToTrash(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) { _items[idx].isDeleted = true; _saveData(); notifyListeners(); }
  }

  void restoreFromTrash(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) { _items[idx].isDeleted = false; _saveData(); notifyListeners(); }
  }

  void deletePermanently(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final file = File(_items[idx].path);
      if (file.existsSync()) file.deleteSync();
      _items.removeAt(idx); _saveData(); notifyListeners();
    }
  }

  void emptyTrash() {
    for (var item in _items.where((e) => e.isDeleted)) {
      final file = File(item.path);
      if (file.existsSync()) file.deleteSync();
    }
    _items.removeWhere((item) => item.isDeleted);
    _saveData(); notifyListeners();
  }

  void createFolder(String name) { _folders.add(GalleryFolder(id: _uuid.v4(), name: name)); _saveData(); notifyListeners(); }
  void deleteFolder(String folderId) {
    _folders.removeWhere((folder) => folder.id == folderId);
    for (var item in _items) { if (item.folderId == folderId) item.folderId = null; }
    _saveData(); notifyListeners();
  }
  void moveItemToFolder(String itemId, String? folderId) {
    final idx = _items.indexWhere((item) => item.id == itemId);
    if (idx != -1) { _items[idx].folderId = folderId; _saveData(); notifyListeners(); }
  }

  Future<void> updateImagePath(String id, String croppedPath) async {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(croppedPath);
      final persistentPath = '${appDir.path}/${_uuid.v4()}.${croppedPath.split('.').last}';
      await file.copy(persistentPath);
      final oldFile = File(_items[idx].path);
      if (oldFile.existsSync()) oldFile.deleteSync();
      _items[idx].path = persistentPath;
      await _saveData(); notifyListeners();
    }
  }
}

// --- WIDGET GRID (OPTIMIZADO) ---
class ImageGrid extends StatelessWidget {
  final List<GalleryItem> images;
  final bool showTrashActions;
  const ImageGrid({super.key, required this.images, this.showTrashActions = false});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const Center(child: Text('No hay imágenes.'));
    final formatter = DateFormat('dd/MM/yy HH:mm');
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8),
      itemCount: images.length,
      itemBuilder: (ctx, i) {
        final item = images[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: showTrashActions ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditScreen(item: item))),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // OPTIMIZACIÓN: cacheWidth evita que la RAM colapse al renderizar múltiples fotos.
                Image.file(File(item.path), fit: BoxFit.cover, cacheWidth: 300),
                Positioned(bottom: 0, left: 0, right: 0, child: Container(color: Colors.black54, padding: const EdgeInsets.all(4), child: Text(formatter.format(item.dateAdded), style: const TextStyle(color: Colors.white, fontSize: 12)))),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: showTrashActions ? [
                        IconButton(icon: const Icon(Icons.restore, color: Colors.greenAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => ctx.read<GalleryProvider>().restoreFromTrash(item.id)),
                        IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 8), constraints: const BoxConstraints(), onPressed: () => ctx.read<GalleryProvider>().deletePermanently(item.id)),
                      ] : [
                        IconButton(icon: Icon(item.isFavorite ? Icons.favorite : Icons.favorite_border, color: item.isFavorite ? Colors.red : Colors.white), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => ctx.read<GalleryProvider>().toggleFavorite(item.id)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 8), constraints: const BoxConstraints(), onPressed: () => ctx.read<GalleryProvider>().moveToTrash(item.id)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- PANTALLAS ---
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    // OPTIMIZACIÓN: imageQuality en 80 evita la saturación de memoria al importar de la cámara
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty && mounted) context.read<GalleryProvider>().addImages(images.map((e) => e.path).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Mi Galería', 'Favoritos', 'Carpetas', 'Papelera'][_idx]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _idx == 2 ? [IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _showCreateFolderDialog)]
               : _idx == 3 ? [IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () => context.read<GalleryProvider>().emptyTrash())] : null,
      ),
      body: Consumer<GalleryProvider>(
        builder: (ctx, prov, _) {
          if (_idx == 0) return ImageGrid(images: prov.allItems);
          if (_idx == 1) return ImageGrid(images: prov.favoriteItems);
          if (_idx == 3) return ImageGrid(images: prov.deletedItems, showTrashActions: true);
          return prov.folders.isEmpty ? const Center(child: Text('No hay carpetas')) : ListView.builder(
            itemCount: prov.folders.length,
            itemBuilder: (ctx, i) {
              final folder = prov.folders[i];
              final items = prov.getItemsInFolder(folder.id);
              return ExpansionTile(
                leading: const Icon(Icons.folder), title: Text(folder.name), subtitle: Text('${items.length} imgs'),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => prov.deleteFolder(folder.id)),
                children: [
                  if (items.isNotEmpty) SizedBox(height: 200, child: ImageGrid(images: items)),
                  TextButton.icon(onPressed: () => _showMoveToFolderDialog(folder), icon: const Icon(Icons.add), label: const Text('Mover aquí'))
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: _idx == 0 ? FloatingActionButton(onPressed: _pickImages, child: const Icon(Icons.add_photo_alternate)) : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Galería'), BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favs'), BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Carpetas'), BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Papelera')],
        currentIndex: _idx, onTap: (i) => setState(() => _idx = i),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Carpeta'), content: TextField(controller: ctrl, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () { if (ctrl.text.isNotEmpty) context.read<GalleryProvider>().createFolder(ctrl.text); Navigator.pop(context); }, child: const Text('Crear'))],
    ));
  }

  void _showMoveToFolderDialog(GalleryFolder folder) {
    final prov = context.read<GalleryProvider>();
    final items = prov.allItems.where((i) => i.folderId != folder.id).toList();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Añadir a ${folder.name}'),
      content: SizedBox(width: double.maxFinite, height: 300, child: items.isEmpty ? const Text('Nada que mover.') : ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ListTile(leading: Image.file(File(items[i].path), width: 50, height: 50, fit: BoxFit.cover, cacheWidth: 100), title: const Text('Mover'), onTap: () { prov.moveItemToFolder(items[i].id, folder.id); Navigator.pop(context); }))),
    ));
  }
}

class EditScreen extends StatefulWidget { final GalleryItem item; const EditScreen({super.key, required this.item}); @override State<EditScreen> createState() => _EditScreenState(); }
class _EditScreenState extends State<EditScreen> {
  final List<Stroke> _strokes = [];
  Stroke? _curr;
  Color _color = Colors.red;
  bool _isEditing = false, _isDrawing = false;
  ColorFilter? _filter;

  Future<void> _crop() async {
    final f = await ImageCropper().cropImage(sourcePath: widget.item.path, compressFormat: ImageCompressFormat.jpg, compressQuality: 90, uiSettings: [AndroidUiSettings(toolbarTitle: 'Recortar', toolbarColor: Colors.deepPurple, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: false)]);
    if (f != null && mounted) { context.read<GalleryProvider>().updateImagePath(widget.item.id, f.path); setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editando' : 'Ver Imagen'), backgroundColor: Colors.black, foregroundColor: Colors.white,
        actions: _isEditing ? [
          IconButton(icon: Icon(_isDrawing ? Icons.edit : Icons.edit_off), onPressed: () => setState(() => _isDrawing = !_isDrawing)),
          IconButton(icon: const Icon(Icons.crop_rotate), onPressed: _crop),
          if (_isDrawing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() { _strokes.clear(); _curr = null; })),
          IconButton(icon: const Icon(Icons.check, color: Colors.greenAccent), onPressed: () => setState(() { _isEditing = false; _isDrawing = false; })),
        ] : [
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: () {
            final folders = context.read<GalleryProvider>().folders;
            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Mover'), content: SizedBox(width: double.maxFinite, child: folders.isEmpty ? const Text('Crea carpetas primero') : ListView.builder(shrinkWrap: true, itemCount: folders.length, itemBuilder: (_, i) => ListTile(title: Text(folders[i].name), onTap: () { context.read<GalleryProvider>().moveItemToFolder(widget.item.id, folders[i].id); Navigator.pop(context); })))));
          }),
          IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ColorFiltered(colorFilter: _filter ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply), child: Image.file(File(widget.item.path), fit: BoxFit.contain)),
                Positioned.fill(
                  child: GestureDetector(
                    onPanStart: (_isEditing && _isDrawing) ? (d) => setState(() => _curr = Stroke([d.localPosition], _color)) : null,
                    onPanUpdate: (_isEditing && _isDrawing) ? (d) => setState(() => _curr?.points.add(d.localPosition)) : null,
                    onPanEnd: (_isEditing && _isDrawing) ? (d) { if (_curr != null) { setState(() { _strokes.add(_curr!); _curr = null; }); } } : null,
                    child: CustomPaint(painter: DrawingPainter(strokes: _strokes, curr: _curr), size: Size.infinite),
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing && !_isDrawing)
            Container(height: 60, color: Colors.grey[900], child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [_btn('Ninguno', null), _btn('B&N', const ColorFilter.matrix([0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0, 0, 0, 1, 0])), _btn('Sepia', const ColorFilter.matrix([0.39, 0.77, 0.19, 0, 0, 0.35, 0.69, 0.17, 0, 0, 0.27, 0.53, 0.13, 0, 0, 0, 0, 0, 1, 0]))])),
          if (_isEditing && _isDrawing)
            Container(
              color: Colors.black, padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 40, margin: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [for (double h = 0; h <= 360; h += 20) HSVColor.fromAHSV(1, h, 1, 1).toColor()])),
                child: SliderTheme(data: SliderThemeData(thumbColor: Colors.white, activeTrackColor: Colors.transparent, inactiveTrackColor: Colors.transparent, overlayColor: Colors.white.withAlpha(76)), child: Slider(value: HSVColor.fromColor(_color).hue, min: 0, max: 360, onChanged: (v) => setState(() => _color = HSVColor.fromAHSV(1, v, 1, 1).toColor()))),
              ),
            ),
        ],
      ),
    );
  }
  Widget _btn(String n, ColorFilter? f) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _filter == f ? Colors.deepPurple : Colors.grey[800], foregroundColor: Colors.white), onPressed: () => setState(() => _filter = f ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)), child: Text(n)));
}

// --- CLASES DE DIBUJO ---
class Stroke { final List<Offset> points; final Color color; Stroke(this.points, this.color); }
class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes; final Stroke? curr; DrawingPainter({required this.strokes, this.curr});
  @override void paint(Canvas c, Size s) { for (var x in strokes) { _p(c, x); } if (curr != null) _p(c, curr!); }
  void _p(Canvas c, Stroke s) { if (s.points.isEmpty) return; final p = Path()..moveTo(s.points.first.dx, s.points.first.dy); for (int i = 1; i < s.points.length; i++) { p.lineTo(s.points[i].dx, s.points[i].dy); } c.drawPath(p, Paint()..color = s.color..strokeWidth = 5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke); }
  @override bool shouldRepaint(covariant DrawingPainter old) => true;
}
