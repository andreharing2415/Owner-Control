import 'package:flutter/material.dart';

/// Widget de skeleton loader animado para indicar carregamento progressivo
/// sem bloquear a UI com spinner centralizado.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton para um card de obra no dashboard — replica o layout real.
class ObraCardSkeleton extends StatelessWidget {
  const ObraCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                SkeletonBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(width: 8),
                Expanded(child: SkeletonBox(width: double.infinity, height: 18)),
                SizedBox(width: 8),
                SkeletonBox(width: 80, height: 22, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 8),
            const SkeletonBox(width: 140, height: 12),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 80, height: 14),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 8),
          ],
        ),
      ),
    );
  }
}

/// Skeleton para a linha de KPIs — replica os 3 cards lado a lado.
class KpiRowSkeleton extends StatelessWidget {
  const KpiRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _kpiCard()),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard()),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard()),
      ],
    );
  }

  Widget _kpiCard() {
    return Card(
      elevation: 0,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(width: 22, height: 22, borderRadius: 4),
            SizedBox(height: 6),
            SkeletonBox(width: 36, height: 20),
            SizedBox(height: 4),
            SkeletonBox(width: 48, height: 11),
          ],
        ),
      ),
    );
  }
}

/// Skeleton completo do dashboard de uma obra (card + KPIs + list-tile).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ObraCardSkeleton(),
        const SizedBox(height: 14),
        const KpiRowSkeleton(),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: const [
                SkeletonBox(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 160, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
