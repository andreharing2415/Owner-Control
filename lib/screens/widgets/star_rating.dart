import 'package:flutter/material.dart';

/// Interactive star rating for forms. Displays 5 tappable stars.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 28,
    this.color = Colors.amber,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starIndex <= rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: starIndex <= rating ? color : Colors.grey[300],
            ),
          ),
        );
      }),
    );
  }
}

/// Display-only star rating with half-star support.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = Colors.amber,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        IconData icon;
        Color iconColor;
        if (rating >= starIndex) {
          icon = Icons.star_rounded;
          iconColor = color;
        } else if (rating >= starIndex - 0.5) {
          icon = Icons.star_half_rounded;
          iconColor = color;
        } else {
          icon = Icons.star_outline_rounded;
          iconColor = Colors.grey[300]!;
        }
        return Icon(icon, size: size, color: iconColor);
      }),
    );
  }
}
