enum AppRoute {
  splash('/'),
  onboarding('/onboarding'),
  signIn('/sign-in'),
  profileSetup('/profile-setup'),
  avatarSelection('/avatar-selection'),
  home('/home'),
  wardrobe('/wardrobe'),
  profile('/profile'),
  upload('/upload'),
  tryOn('/try-on'),
  camera('/camera'),
  cameraTryOn('/camera-try-on'),
  aiFeedback('/feedback'),
  styleTips('/style-tips');

  const AppRoute(this.path);

  final String path;
}
