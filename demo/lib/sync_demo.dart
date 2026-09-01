import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import 'text_card.dart';
import 'utils.dart';

class SyncDemo extends StatefulWidget {
  const SyncDemo(this.richText, {super.key});

  final bool richText;

  @override
  State<SyncDemo> createState() => _SyncDemoState();
}

class _SyncDemoState extends State<SyncDemo>
    with SingleTickerProviderStateMixin {
  double _scale = 0;
  final AutoSizeGroup _group = AutoSizeGroup();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _controller.addListener(() {
      setState(() {
        _scale = _controller.value;
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (!mounted) {
            return;
          }
          _controller.forward(from: 0.1);
        });
      }
    });

    _controller.forward(from: 0.1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const text =
        'These AutoSizeTexts fit the available space and synchronize their '
        'text sizes.';
    return Column(
      children: <Widget>[
        Expanded(
          child: TextCard(
            title: 'AutoSizeText 1',
            child: Visibility(
              visible: !widget.richText,
              replacement: AutoSizeText.rich(
                spanFromString(text),
                group: _group,
                style: const TextStyle(fontSize: 40),
                stepGranularity: 0.1,
                maxLines: 4,
              ),
              child: AutoSizeText(
                text,
                group: _group,
                style: const TextStyle(fontSize: 40),
                stepGranularity: 0.1,
                maxLines: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                flex: ((1000 - _scale * 1000) / 2).round(),
                child: const SizedBox.shrink(),
              ),
              Flexible(
                key: const ValueKey<String>('sync-resizing-text'),
                flex: (_scale * 1000).round(),
                child: TextCard(
                  title: 'AutoSizeText 2',
                  child: Visibility(
                    visible: !widget.richText,
                    replacement: AutoSizeText.rich(
                      spanFromString(text),
                      group: _group,
                      style: const TextStyle(fontSize: 40),
                      stepGranularity: 0.1,
                      maxLines: 4,
                    ),
                    child: AutoSizeText(
                      text,
                      group: _group,
                      style: const TextStyle(fontSize: 40),
                      stepGranularity: 0.1,
                      maxLines: 3,
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: ((1000 - _scale * 1000) / 2).round(),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
