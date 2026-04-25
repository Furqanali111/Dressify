enum AppRoute {
  splash('/'),
  signIn('/sign-in'),
  profileSetup('/profile-setup'),
  avatarSelection('/avatar-selection'),
  home('/home'),
  wardrobe('/wardrobe'),
  profile('/profile'),
  upload('/upload'),
  tryOn('/try-on'),
  aiFeedback('/feedback');

  const AppRoute(this.path);

  final String path;
}
