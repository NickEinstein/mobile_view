import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/places/bundled_place_names.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// The Profile tab: the signed-in registrar's details.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.select((AuthBloc bloc) => bloc.state);
    return switch (auth) {
      AuthAuthenticated(:final user) => ProfileView(user: user),
      _ => const SizedBox.shrink(),
    };
  }
}

class ProfileView extends StatefulWidget {
  const ProfileView({required this.user, this.placeNames, super.key});

  final User user;

  /// Defaults to the bundled lists; tests pass their own.
  final BundledPlaceNames? placeNames;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Future<(String?, String?)> _places = _loadPlaces();

  Future<(String?, String?)> _loadPlaces() async {
    final names = widget.placeNames ?? BundledPlaceNames();
    return (
      await names.state(widget.user.stateId),
      await names.lga(widget.user.lgaId),
    );
  }

  @override
  void didUpdateWidget(ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) _places = _loadPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = widget.user;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        FutureBuilder(
          future: _places,
          builder: (context, snapshot) {
            final (state, lga) = snapshot.data ?? (null, null);
            return _ProfileCard(
              user: user,
              details: [
                (Icons.person_outline, l10n.profileUserName, user.userName),
                (Icons.mail_outline, l10n.profileEmail, user.email),
                (Icons.phone_outlined, l10n.profilePhone, user.phone),
                (Icons.apartment_outlined, l10n.profileCentre, user.centreName),
                (Icons.map_outlined, l10n.profileState, state),
                (Icons.location_on_outlined, l10n.profileLga, lga),
              ],
            );
          },
        ),
      ],
    );
  }
}

typedef _Detail = (IconData icon, String label, String? value);

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.details});

  final User user;

  /// Shown only when they have a value.
  final List<_Detail> details;

  /// Up to two initials from the full name.
  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppPalette.cardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppPalette.brand,
                  foregroundColor: Colors.white,
                  child: Text(
                    _initials(user.fullName),
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppPalette.inkStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.chipFill,
                          borderRadius: BorderRadius.circular(Spacing.xs),
                        ),
                        child: Text(
                          user.roleName ?? l10n.profileRegistrar,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppPalette.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            const Divider(height: 1, color: AppPalette.cardBorder),
            for (final (icon, label, value) in details)
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: AppPalette.muted),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppPalette.muted,
                              ),
                            ),
                            Text(
                              value,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppPalette.inkStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
