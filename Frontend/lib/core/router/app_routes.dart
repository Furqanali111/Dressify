enum AppRoute {
  splash('/'),
  signIn('/sign-in'),
  profileSetup('/profile-setup'),
  avatarSelection('/avatar-selection'),
  home('/home'),
  upload('/upload'),
  tryOn('/try-on'),
  wardrobe('/wardrobe'),
  profile('/profile');

  const AppRoute(this.path);

  final String path;
}
