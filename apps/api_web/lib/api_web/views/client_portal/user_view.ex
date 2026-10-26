defmodule ApiWeb.ClientPortal.UserView do
  use ApiWeb.Web, :view

  # No client input is used: the widget is rendered from the configured public key.
  # sobelow_skip ["XSS.Raw"]
  def recaptcha_widget do
    raw(Recaptcha.Template.display(callback: "recaptchaCompleted"))
  end
end
