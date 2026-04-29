import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class KidSafeAdBanner extends StatefulWidget {
  const KidSafeAdBanner({super.key});

  @override
  State<KidSafeAdBanner> createState() => _KidSafeAdBannerState();
}

class _KidSafeAdBannerState extends State<KidSafeAdBanner> {
  static const List<String> _facts = [
    "Musical notation was invented by monks in the Middle Ages.",
    "The world's oldest known musical instrument is a flute made from a vulture bone.",
    "Listening to music can help your brain focus and learn better!",
    "A piano has 88 keys: 52 white keys and 36 black keys.",
    "The 'Mozart Effect' suggests that listening to classical music can temporarily boost spatial reasoning.",
    "Your heart rate can change to mimic the music you are listening to.",
    "The longest musical performance ever started in 2001 and is scheduled to end in 2640!",
    "Termites eat wood twice as fast when they listen to heavy metal music.",
    "The guitar was originally developed in Spain in the 16th century.",
    "Beethoven continued to compose music even after he became completely deaf.",
  ];

  late String _currentFact;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentFact = _facts[Random().nextInt(_facts.length)];
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {
          _currentFact = _facts[Random().nextInt(_facts.length)];
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DID YOU KNOW?',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.1,
                      ),
                ),
                Text(
                  _currentFact,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
