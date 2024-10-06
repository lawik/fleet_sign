defmodule FleetSignWeb.ActionLive do
  use FleetSignWeb, :live_view

  import SweetXml

  def mount(_, _, socket) do
    Phoenix.PubSub.subscribe(FleetSign.PubSub, "presigns")
    send(self(), :refresh)
    {:ok, assign(socket, latest_podcasts: [])}
  end

  def handle_info({:signed, _key}, socket) do
    {:noreply, socket}
  end

  def handle_info(:refresh, socket) do
    latest_podcast_keys = fetch_latest_podcasts()
    Process.send_after(self(), :refresh, 3000)

    {:noreply, assign(socket, latest_podcasts: latest_podcast_keys)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex">
      <div id="latest-podcasts" class="">
        <h2 class="text-2xl my-2">Podcasts</h2>
        <div :for={key <- @latest_podcasts} id={key}>
          <%= key %>
        </div>
      </div>
    </div>
    """
  end

  defp fetch_latest_podcasts do
    Req.get!("https://fly.storage.tigris.dev/nerves-fleet-data/",
      params: %{
        "list-type" => 2,
        "prefix" => "shared/podcasts",
        "max-keys" => 20
      },
      headers: %{
        "X-Tigris-Query" => "`Content-Length` > 0 ORDER BY \`Last-Modified\` DESC"
      },
      max_retries: 0
    )
    |> Map.fetch!(:body)
    |> SweetXml.xpath(~x"//ListBucketResult/Contents/Key/text()"l)
    |> Enum.map(&to_string/1)
  end
end
