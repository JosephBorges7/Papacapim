// ============================================================
// ARQUIVO: screens/create_post_screen.dart
// FUNÇÃO: Tela para criar uma publicação ou responder a um post
//         enviando para a API (POST /posts ou POST /posts/{id}/replies).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../providers/app_state.dart';

// StatefulWidget para gerenciar o estado do campo de texto e envio à API.
class CreatePostScreen extends StatefulWidget {
  // ID do post original (se for uma resposta).
  final String? parentPostId;

  const CreatePostScreen({super.key, this.parentPostId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // Controlador do campo de texto.
  final _contentController = TextEditingController();

  // Estado de envio
  bool _isLoading = false;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // ── Função: escolher imagem da galeria ou da câmera ──────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar imagem')),
      );
    }
  }

  // ── Função: abrir opções de origem da imagem ─────────────────
  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Função: publicar post ou resposta na API ─────────────────
  Future<void> _submit() async {
    final text = _contentController.text.trim();
    // Permite publicar com texto, com imagem, ou com os dois.
    if (text.isEmpty && _imageBytes == null) return;

    setState(() => _isLoading = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final success = await appState.createPost(
      text.isEmpty ? '(imagem)' : text,
      parentPostId: widget.parentPostId,
      base64Image: _imageBytes != null ? base64Encode(_imageBytes!) : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.lastErrorMessage ?? 'Falha ao enviar postagem'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Construção da interface visual ───────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Barra superior ──────────────────────────────────────
      appBar: AppBar(
        title: Text(widget.parentPostId == null ? 'Nova Postagem' : 'Responder Post'),
        actions: [
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submit,
                ),
        ],
      ),

      // ── Corpo da tela: campo de texto ────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 8,
              minLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.parentPostId == null
                    ? 'O que está acontecendo?'
                    : 'Escreva sua resposta...',
                border: InputBorder.none,
              ),
            ),

            // ── Pré-visualização da imagem anexada ──
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Botão para remover a imagem escolhida
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => setState(() => _imageBytes = null),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // ── Botão de anexar imagem ──
            TextButton.icon(
              onPressed: _showImageOptions,
              icon: const Icon(Icons.image_outlined),
              label: Text(_imageBytes == null ? 'Adicionar imagem' : 'Trocar imagem'),
            ),
          ],
        ),
      ),
    );
  }
}
