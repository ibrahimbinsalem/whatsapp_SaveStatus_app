import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppColors.primary;
    final textColor = _resolveTextColor(buttonColor, isOutlined);
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: buttonColor, width: 1.5),
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              child: _buildChild(textColor),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                elevation: 0,
                shadowColor: buttonColor.withOpacity(0.15),
              ),
              child: _buildChild(textColor),
            ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: textColor,
          strokeWidth: 2.5,
        ),
      );
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }

  Color _resolveTextColor(Color background, bool isOutlined) {
    if (isOutlined) {
      return background;
    }
    if (background == Colors.white || background == AppColors.surface) {
      return AppColors.primary;
    }
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark
        ? AppColors.textOnPrimary
        : AppColors.textPrimary;
  }
}
