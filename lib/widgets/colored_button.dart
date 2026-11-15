import 'package:flutter/material.dart';

class ColoredButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onPressed;
  final Widget? child;

  const ColoredButton({
    super.key,
    required this.color,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: color),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(
          Color.from(
            alpha: color.a / 8.0,
            red: color.r,
            green: color.g,
            blue: color.b,
          ),
        ),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
      ),
      child: child,
    );
  }
}
