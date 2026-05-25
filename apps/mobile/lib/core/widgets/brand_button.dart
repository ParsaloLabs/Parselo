import 'package:flutter/material.dart';
import '../theme/theme.dart';

class BrandButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Color textColor;
  final bool isSecondary;
  final double height;
  final double borderRadius;
  final Widget? icon;

  const BrandButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.color,
    this.textColor = Colors.white,
    this.isSecondary = false,
    this.height = 52,
    this.borderRadius = 12,
    this.icon,
  }) : super(key: key);

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.loading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.loading) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final defaultBg = widget.isSecondary 
        ? Colors.white 
        : (widget.color ?? AppColors.brand);
        
    final defaultBorder = widget.isSecondary
        ? const BorderSide(color: AppColors.border, width: 1.5)
        : BorderSide.none;

    final defaultTextCol = widget.isSecondary
        ? AppColors.textPrimary
        : widget.textColor;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: (widget.onPressed == null || widget.loading) 
          ? null 
          : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Opacity(
          opacity: widget.onPressed == null ? 0.6 : 1.0,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: defaultBg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.fromBorderSide(defaultBorder),
              boxShadow: (widget.isSecondary || widget.onPressed == null) ? [] : [
                BoxShadow(
                  color: (widget.color ?? AppColors.brand).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: widget.loading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isSecondary ? AppColors.brand : Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: defaultTextCol,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
