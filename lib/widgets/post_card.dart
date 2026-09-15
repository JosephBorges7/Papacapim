// ============================================================
// ARQUIVO: widgets/post_card.dart
// FUNÇÃO: Widget de exibição de um post no feed com ações
//         de curtir, responder e excluir integradas à API.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/post.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../screens/profile_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/post_detail_screen.dart';

// Widget sem estado para exibir os dados de um post.
class PostCard extends StatelessWidget {
  // Post a ser exibido.
  final Post post;

  const PostCard({super.key, required this.post});

  // ── Confirmação de exclusão do post ──────────────────────────
  void _confirmDelete(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Postagem'),
        content: const Text('Deseja realmente apagar esta publicação do servidor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deletePost(post.id);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // Obtém dados do autor e verifica o estado do post.
    final user    = post.author ?? appState.getUserById(post.userId);
    final isMe    = appState.currentUser?.login == user.login ||
                    appState.currentUser?.id == user.login;
    final isLiked = post.youLiked || appState.isLiked(post.id);

    // Cartão macio para cada post (sem margens laterais no feed dá mais cara de mobile)
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho do post ──
            Row(
              children: [
                // Avatar (navega para o perfil ao tocar)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: user.login),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: user.avatarProvider,
                  ),
                ),

                const SizedBox(width: 12),

                // Nome e @username do autor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '@${user.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                      // Indica se é uma resposta a outro post
                      if (post.parentPostId != null)
                        Builder(
                          builder: (context) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(postId: post.parentPostId!),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Em resposta a post #${post.parentPostId}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                        ),
                    ],
                  ),
                ),

                // Botão de deletar (apenas para o próprio autor)
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.softCoral),
                    onPressed: () => _confirmDelete(context, appState),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Texto do post
            Text(
              post.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            Builder(builder: (context) {
              final apiImg = post.apiImageUrl;
              final localImg = appState.postImages[post.id];

              if (apiImg != null && apiImg.startsWith('http')) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(apiImg, width: double.infinity, fit: BoxFit.cover),
                  ),
                );
              }
              final b64 = apiImg ?? localImg;
              if (b64 != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(b64), width: double.infinity, fit: BoxFit.cover),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 12),

            // ── Interações (Curtir e Responder) ──
            Row(
              children: [
                // Botão de curtir (POST /posts/{id}/likes e DELETE /posts/{id}/likes/me)
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppTheme.softCoral : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    appState.toggleLike(post.id);
                  },
                ),
                Text('${post.likes}'),

                const SizedBox(width: 16),

                // Botão de responder (POST /posts/{id}/replies)
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePostScreen(parentPostId: post.id),
                      ),
                    );
                  },
                ),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(postId: post.id),
                      ),
                    );
                  },
                  child: Text(
                    post.repliesCount > 0 ? '${post.repliesCount} respostas' : 'Responder',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}