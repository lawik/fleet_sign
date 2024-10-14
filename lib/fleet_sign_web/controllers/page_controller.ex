defmodule FleetSignWeb.PageController do
  use FleetSignWeb, :controller

  @open_secret "ti2zRfSCr3ITpMU9ReghbGvsy8EOW+VbfAfy18oe59o="
  @namespace "redo"
  def presign(conn, %{
        "key" => key,
        "secret" => secret,
        "serial_number" => _serial_number,
        "method" => method
      })
      when secret == @open_secret do
    path = Path.join(@namepsace, key)

    presign =
      case method do
        "post" -> Tigris.presign_post(path)
        "get" -> Tigris.presign_get(path)
      end

    Phoenix.PubSub.broadcast(FleetSign.PubSub, "presigns", {:signed, path})
    json(conn, %{presigned_upload: presign})
  end

  def presign(conn, %{"secret" => secret, "serial_number" => serial_number, "method" => method})
      when secret == @open_secret do
    path = Path.join(["data", serial_number, "location.json"])

    presign =
      case method do
        "post" -> Tigris.presign_post(path)
        "get" -> Tigris.presign_get(path)
      end

    Phoenix.PubSub.broadcast(FleetSign.PubSub, "presigns", {:signed, path})
    json(conn, %{presigned_upload: presign})
  end
end
