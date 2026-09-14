// ============================================================
// ARQUIVO: screens/profile_screen.dart
// FUNÇÃO: Tela de perfil do usuário, exibindo foto, 
//         estatísticas e seus posts consumindo a API Papacapim.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../widgets/post_card.dart';
import 'edit_profile_screen.dart';

// Tela de exibição de perfil do usuário (próprio ou de terceiros).
class ProfileScreen extends StatefulWidget {
  // Login do usuário exibido nesta tela (compatível com o identificador).
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  List<Post> _userPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // ── Carrega os dados atualizados do perfil e postagens da API ─
  Future<void> _loadProfileData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = await appState.fetchUserProfile(widget.userId);
    final posts = await appState.fetchUserPosts(widget.userId);

    if (!mounted) return;
    setState(() {
      _user = user ?? appState.getUserById(widget.userId);
      _userPosts = posts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // Usuário exibido (com fallback para o cache ou o próprio currentUser)
    final user = _user ?? appState.getUserById(widget.userId);

    // Identifica o perfil atual para ocultar/mostrar botões específicos.
    final isMe = appState.currentUser?.login == widget.userId ||
        appState.currentUser?.id == widget.userId;
    final isFollowing = user.youFollow || appState.isFollowing(widget.userId);

    return Scaffold(
      appBar: AppBar(title: Text(user.username)),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: Column(
                children: [
                  // ── Seção superior: foto e informações ──────
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Foto de perfil
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: user.avatarProvider,
                        ),

                        const SizedBox(width: 24),

                        // Estatísticas e Botão de ação
                        Expanded(
                          child: Column(
                            children: [
                              // Contadores
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatColumn(context, 'Posts',      _userPosts.length),
                                  _buildStatColumn(context, 'Seguidores', user.followers),
                                  _buildStatColumn(context, 'Seguindo',   user.following),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Botão Editar Perfil ou Seguir
                              isMe
                                  ? OutlinedButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const EditProfileScreen(),
                                          ),
                                        );
                                        _loadProfileData();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(36),
                                      ),
                                      child: const Text('Editar Perfil'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () async {
                                        await appState.toggleFollow(widget.userId);
                                        _loadProfileData();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(36),
                                      ),
                                      child: Text(isFollowing ? 'Deixar de Seguir' : 'Seguir'),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Nome de exibição ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),

                  const Divider(),

                  // ── Lista de posts do usuário ────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadProfileData,
                      child: _userPosts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.eco,
                                          size: 60,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhum post ainda!',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _userPosts.length,
                              itemBuilder: (context, index) => PostCard(post: _userPosts[index]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Método auxiliar: coluna de estatística ───────────────────
  Column _buildStatColumn(BuildContext context, String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          label, 
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
