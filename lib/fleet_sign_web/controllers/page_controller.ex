defmodule FleetSignWeb.PageController do
  use FleetSignWeb, :controller

  @open_secret "ti2zRfSCr3ITpMU9ReghbGvsy8EOW+VbfAfy18oe59o="
  def presign(conn, %{"secret" => secret, "serial_number" => serial_number})
      when secret == @open_secret do
    path = Path.join(["data", serial_number, "location.json"])
    presign = Tigris.presign_post(path)
    json(conn, %{presigned_upload: presign})
  end
end
