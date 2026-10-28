import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/common/result.dart';
import '../../../domain/entities/user_entity.dart' hide AuthProvider;
import '../../../domain/usecases/storage_usecases.dart';
import '../../../domain/usecases/user_usecases.dart';
import '../auth/auth_notifier.dart';
import '../main/main_notifier.dart';
import 'account_state.dart';

final accountNotifierProvider = NotifierProvider.autoDispose<AccountNotifier, AccountFormState>(
  AccountNotifier.new,
);

class AccountNotifier extends AutoDisposeNotifier<AccountFormState> {
  @override
  AccountFormState build() {
    return const AccountFormState();
  }

  String _requireUserId() {
    final authState = ref.read(authNotifierProvider);
    if (authState.isAuthenticated) return authState.user!.id;
    throw 'Unauthenticated!';
  }

  Future<void> initProfileForm() async {
    final userId = _requireUserId();
    final userRepository = ref.read(userRepositoryProvider);
    final authUser = ref.read(authNotifierProvider).user;

    try {
      var res = await GetUserUsecase(userRepository).call(userId);

      if (res.isSuccess && res.data != null) {
        state = state.copyWith(
          imageUrl: res.data?.imageUrl ?? authUser?.imageUrl,
          name: res.data?.name ?? authUser?.name,
          email: res.data?.email ?? authUser?.email,
          phone: res.data?.phone ?? authUser?.phone,
          isLoaded: true,
        );
        return;
      }
    } catch (_) {}

    // Fallback to authUser if Firestore document doesn't exist or failed to load
    state = state.copyWith(
      imageUrl: authUser?.imageUrl,
      name: authUser?.name ?? 'User',
      email: authUser?.email,
      phone: authUser?.phone,
      isLoaded: true,
    );
  }

  Future<Result<void>> updatedUser() async {
    try {
      final userId = _requireUserId();
      final storageRepository = ref.read(storageRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final authUser = ref.read(authNotifierProvider).user;

      var imageUrl = state.imageUrl;

      if (state.imageFile != null) {
        final res = await UploadUserPhotoUsecase(storageRepository).call(state.imageFile!.path);
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          imageUrl = res.data;
        } else {
          imageUrl = state.imageFile!.path;
        }
      }

      final resolvedName = (state.name != null && state.name!.trim().isNotEmpty)
          ? state.name!.trim()
          : (authUser?.name?.trim().isNotEmpty == true ? authUser!.name : 'User');

      var user = UserEntity(
        id: userId,
        email: state.email ?? authUser?.email,
        phone: state.phone ?? authUser?.phone,
        name: resolvedName,
        imageUrl: imageUrl ?? '',
      );

      var res = await UpateUserUsecase(userRepository).call(user);

      if (res.isSuccess) {
        ref.read(authNotifierProvider.notifier).updateUser(user);
        try {
          ref.read(mainNotifierProvider.notifier).getAndSyncAllUserData();
        } catch (_) {}
      }

      return res;
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  void onChangedImage(File value) {
    state = state.copyWith(imageFile: value);
  }

  void onChangedName(String value) {
    state = state.copyWith(name: value);
  }

  void onChangedEmail(String value) {
    state = state.copyWith(email: value);
  }

  void onChangedPhone(String value) {
    state = state.copyWith(phone: value);
  }
}
