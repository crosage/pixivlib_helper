import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ModifyText extends StatefulWidget {
  final String hintText;
  final Function onDelete;
  final Function onUpdate;

  const ModifyText(
      {Key? key,
      required this.hintText,
      required this.onDelete,
      required this.onUpdate})
      : super(key: key);

  @override
  _ModifyTextState createState() => _ModifyTextState();
}

class _ModifyTextState extends State<ModifyText> {
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isEditing)
          Container(
            width: 500,
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 16
                )
              ),
            ),
          )
        else
          Container(
            width: 500,
            child: Text(
              widget.hintText,
              style: TextStyle(
                  fontSize: 16
              )
            ),
          ),
        IconButton(
          onPressed: () async {
            setState(() {
              isEditing = !isEditing;
            });
          },
          icon: Icon(Icons.edit),
        ),
        IconButton(
          onPressed: () async {
            widget.onDelete;
            setState(() {});
          },
          icon: Icon(Icons.delete),
        ),
      ],
    );
  }
}
