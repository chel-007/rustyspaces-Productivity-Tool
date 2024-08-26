import 'package:flutter/material.dart';

class TwoStateCheckbox extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  const TwoStateCheckbox({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _TwoStateCheckboxState createState() => _TwoStateCheckboxState();
}

class _TwoStateCheckboxState extends State<TwoStateCheckbox> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _toggleValue() {
    setState(() {
      _value = !_value;
      widget.onChanged(_value);
    });
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = _value ? Icons.check : Icons.cancel;
    Color iconColor = _value ? Colors.green : Colors.red;

    return IconButton(
      icon: Icon(icon, color: iconColor, size: 20),
      onPressed: _toggleValue,
    );
  }
}
