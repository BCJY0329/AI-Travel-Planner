import 'package:flutter/material.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import 'chat_bubble.dart';
import 'lemon_avatar_image.dart';

class LemonChatPanel extends StatefulWidget {
  final LemonChatController controller;
  final VoidCallback onClose;

  const LemonChatPanel({super.key, required this.controller, required this.onClose});

  @override
  State<LemonChatPanel> createState() => _LemonChatPanelState();
}

class _LemonChatPanelState extends State<LemonChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    widget.controller.handleUserInput(text);
    _textController.clear();
  }

  Future<void> _pickDate(DateTime? minDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // For the departure date, minDate is null -> floor at today.
    // For the return date, the controller passes (departureDate + 1 day) so
    // the calendar can't show anything on or before the chosen departure date.
    final firstSelectable = minDate ?? today;
    final initial = firstSelectable.isAfter(today) ? firstSelectable : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstSelectable,
      lastDate: firstSelectable.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final iso =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      widget.controller.handleUserInput(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width < 500 ? size.width - 24 : 390.0;
    final panelHeight = size.height < 680 ? size.height - 100 : 560.0;

    return Material(
      elevation: 12,
      shadowColor: AppTheme.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1.2),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildProviderRow(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: widget.controller.messages.length,
                itemBuilder: (context, index) {
                  final msg = widget.controller.messages[index];
                  return ChatBubbleWidget(
                    message: msg,
                    onQuickReply: widget.controller.handleQuickReply,
                    onPickDate: _pickDate,
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(19),
          topRight: Radius.circular(19),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const LemonAvatarImage(radius: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Lemon.ai',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLemon,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TRIP GENIE',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF86EFAC),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ready to plan your next trip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: widget.onClose,
            tooltip: 'Close Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRow() {
    const options = ['mock', 'claude', 'gpt', 'gemini'];
    final busy = widget.controller.isBusy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          const SizedBox(height: 8),
          const Text(
            'AI engine',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((opt) {
                  final selected = widget.controller.provider == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: busy ? null : () => widget.controller.setProvider(opt),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.lavenderTint : AppTheme.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppTheme.primary : AppTheme.border,
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                            color: selected ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(19),
          bottomRight: Radius.circular(19),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'e.g. "5 days in Osaka this December, food + temples"',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _send,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }
}