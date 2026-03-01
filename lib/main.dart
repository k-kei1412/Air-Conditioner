import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: NojimaThreeCalcPage(),
  ));
}

class NojimaThreeCalcPage extends StatefulWidget {
  const NojimaThreeCalcPage({super.key});
  @override
  State<NojimaThreeCalcPage> createState() => _NojimaThreeCalcPageState();
}

class _NojimaThreeCalcPageState extends State<NojimaThreeCalcPage> {
  final formatter = NumberFormat("#,###");
  List<String> modelNames = ["機種 1", "機種 2", "機種 3"];
  List<List<dynamic>> allData = [[], [], []];
  
  int selectedIndex = 0; 
  String currentInput = "0"; 
  bool isNegative = false;
  bool isLeftPanelVisible = true; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('nojima_final_v15');
    final List<String>? savedNames = prefs.getStringList('nojima_names_v15');
    setState(() {
      if (jsonStr != null) {
        Iterable l = json.decode(jsonStr);
        allData = List<List<dynamic>>.from(l.map((model) => List<dynamic>.from(model)));
      }
      if (savedNames != null) modelNames = savedNames;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nojima_final_v15', json.encode(allData));
    await prefs.setStringList('nojima_names_v15', modelNames);
  }

  void _handleKey(String key) {
    setState(() {
      if (key == "C") { currentInput = "0"; isNegative = false; }
      else if (key == "±") { isNegative = !isNegative; }
      else if (key == "BS") { currentInput = currentInput.length > 1 ? currentInput.substring(0, currentInput.length - 1) : "0"; }
      else {
        if (currentInput == "0" && key != "00") currentInput = "";
        if (currentInput == "0" && key == "00") return;
        currentInput += key;
      }
    });
  }

  void _addItem(String name, {double? fixedPrice, bool isMinus = false}) {
    setState(() {
      double val = fixedPrice ?? (double.tryParse(currentInput) ?? 0);
      if (isMinus || (fixedPrice == null && isNegative)) val = -val.abs();
      allData[selectedIndex].add({"name": name, "price": val});
      currentInput = "0"; 
      isNegative = false;
      _saveData();
    });
  }

  void _editModelName(int index) {
    TextEditingController controller = TextEditingController(text: modelNames[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('機種名の変更'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "例: ダイキン 6畳")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(onPressed: () {
            setState(() { modelNames[index] = controller.text; _saveData(); });
            Navigator.pop(context);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _editItemPrice(int modelIdx, int itemIdx) {
    TextEditingController controller = TextEditingController(text: allData[modelIdx][itemIdx]['price'].toInt().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${allData[modelIdx][itemIdx]['name']} の修正'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "円")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(onPressed: () {
            setState(() {
              allData[modelIdx][itemIdx]['price'] = double.tryParse(controller.text) ?? 0;
              _saveData();
            });
            Navigator.pop(context);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _showMenu(String title, Map<String, double> items) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            ...items.entries.map((e) => ListTile(
              title: Text(e.key),
              trailing: Text("¥${formatter.format(e.value)}"),
              onTap: () { _addItem(e.key, fixedPrice: e.value); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isLeftPanelVisible ? Icons.menu_open : Icons.menu, color: Colors.white),
          onPressed: () => setState(() => isLeftPanelVisible = !isLeftPanelVisible),
        ),
        title: const Text('エアコン用電卓-AirSave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[600],
        actions: isPortrait ? [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => selectedIndex = (selectedIndex - 1 + 3) % 3)),
          Center(child: Text('${selectedIndex + 1}/3', style: const TextStyle(color: Colors.white, fontSize: 18))),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => selectedIndex = (selectedIndex + 1) % 3)),
        ] : null,
      ),
      body: Row(
        children: [
          if (isLeftPanelVisible)
            Container(width: 260, color: Colors.blueGrey[50], child: _buildLeftPanel()),
          Expanded(child: isPortrait ? _buildPriceColumn(selectedIndex) : Row(children: List.generate(3, (i) => Expanded(child: _buildPriceColumn(i))))),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12),
          width: double.infinity, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue[300]!, width: 2), borderRadius: BorderRadius.circular(8)),
          child: Text("${isNegative ? '-' : ''}${formatter.format(double.tryParse(currentInput) ?? 0)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey), textAlign: TextAlign.right),
        ),
        _buildNumPad(),
        const Divider(height: 20),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
          _itemBtn("エアコン本体", Colors.blue[700]!, () => _addItem("本体")),
          _itemBtn("標準工事 (18,150円)", Colors.green[700]!, () => _addItem("標準工事", fixedPrice: 18150)),
          _itemBtn("室外機取り付けメニュー", Colors.orange[700]!, () => _showMenu("室外機取り付け", {"2F→1F高所": 7700, "3F→1F高所": 12000, "施策適用": -6600})),
          _itemBtn("配管カバーメニュー", Colors.cyan[700]!, () => _showMenu("配管カバー", {"施策適用": -5500, "カバーなし": -5500, "再利用": 8800})),
          _itemBtn("室外機階段上げ", Colors.deepPurple[600]!, () => _showMenu("室外機階段上げ", {"内階段上げ": 1100, "内階段上げ(4.0kw以上)": 2200, "内階段上げ(加湿喚起タイプ)": 4400, "外階段上げ(感動エアコン)": 1100})),
          _itemBtn("特殊工事", Colors.grey[700]!, () => _addItem("特殊工事")),
          _itemBtn("リサイクル (4,070円)", Colors.teal[600]!, () => _addItem("リサイクル", fixedPrice: 4070)),
          _itemBtn("値引き", Colors.red[600]!, () => _addItem("値引き", isMinus: true)),
          const SizedBox(height: 20),
        ])),
      ],
    );
  }

  Widget _buildNumPad() {
    List<String> keys = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "±", "0", "00", "BS", "C"];
    return Wrap(alignment: WrapAlignment.center, children: keys.map((k) => SizedBox(
      width: 80, height: 50,
      child: Card(elevation: 2, color: (k == "C" || k == "BS") ? Colors.red[50] : (k == "±" ? Colors.blue[50] : Colors.white), 
        child: InkWell(onTap: () => _handleKey(k), child: Center(child: Text(k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
    )).toList());
  }

  Widget _itemBtn(String label, Color col, VoidCallback tap) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: col, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: tap, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))));
  }

  Widget _buildPriceColumn(int index) {
    bool active = selectedIndex == index;
    double total = allData[index].fold(0.0, (sum, item) => sum + (item['price'] as double));
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index), 
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(border: Border.all(color: active ? Colors.blue[600]! : Colors.grey[300]!, width: active ? 4 : 1), borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null),
        child: Column(children: [
          InkWell(
            onLongPress: () => _editModelName(index), 
            child: Container(height: 50, color: active ? Colors.blue[600] : Colors.grey[400], padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(modelNames[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.white, size: 22), onPressed: () => setState(() { allData[index] = []; _saveData(); })),
              ])),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = allData[index].removeAt(oldIdx);
                  allData[index].insert(newIdx, item);
                  _saveData();
                });
              },
              children: [
                for (int i = 0; i < allData[index].length; i++)
                  Container(
                    key: ValueKey("item-$index-${allData[index][i]['name']}-$i"),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                    child: ListTile(
                      onTap: () => _editItemPrice(index, i),
                      title: Text(allData[index][i]['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text("¥${formatter.format(allData[index][i]['price'])}", 
                        style: TextStyle(
                          color: allData[index][i]['price'] < 0 ? Colors.red[700] : Colors.black,
                          fontWeight: FontWeight.w900, 
                          fontSize: 22, 
                        )),
                      // ★ 右側に「その行を消す」ボタンを追加
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                        onPressed: () {
                          setState(() {
                            allData[index].removeAt(i);
                            _saveData();
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(padding: const EdgeInsets.all(15), width: double.infinity, decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('合計（税込）', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              Text("¥${formatter.format(total)}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red[700])),
            ])),
        ]),
      ),
    );
  }
}
