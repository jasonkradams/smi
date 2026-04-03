var Security = {
  setupSalt: function () {
    const p = PropertiesService.getScriptProperties();
    if (!p.getProperty("EMAIL_SALT"))
      p.setProperty("EMAIL_SALT", Utilities.getUuid());
  },
  computeHash: function (input) {
    return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, input)
      .map((b) => ("0" + (b & 0xff).toString(16)).slice(-2))
      .join("");
  }
};
