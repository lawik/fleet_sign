defmodule FleetSignWeb.ActionLive do
  use FleetSignWeb, :live_view

  import SweetXml

  def mount(_, _, socket) do
    Phoenix.PubSub.subscribe(FleetSign.PubSub, "presigns")
    send(self(), :refresh)
    {:ok, assign(socket, latest_podcasts: [], fetched: %{}, latest_signed: [])}
  end

  def handle_info({:signed, key}, socket) do
    latest_signed = [key | Enum.take(socket.assigns.latest_signed, 12)]
    {:noreply, assign(socket, latest_signed: latest_signed)}
  end

  def handle_info(:refresh, socket) do
    latest_podcast_keys = fetch_latest_podcasts()
    Process.send_after(self(), :refresh, 3000)

    socket = assign(socket, latest_podcasts: latest_podcast_keys)

    fetched =
      socket.assigns.latest_podcasts
      |> Task.async_stream(fn key ->
        {key, fetch(key)}
      end)
      |> Enum.map(fn {:ok, {key, {:ok, data}}} ->
        {key, data}
      end)
      |> Map.new()

    {:noreply, assign(socket, fetched: fetched)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex gap-4">
      <div id="latest-signed" class="basis-1/2">
        <h2 class="text-2xl my-2 mb-4">Signed</h2>
        <div :for={key <- @latest_signed} id={"signed" <> key} class="my-2">
          <div class="text-bold"><%= key %></div>
          <div class="inline text-slate-400 text-xs overflow-hidden">&nbsp;</div>
        </div>
      </div>

      <div id="latest-podcasts" class="basis-1/2">
        <h2 class="text-2xl my-2 mb-4">Podcasts</h2>
        <div :for={key <- @latest_podcasts} id={key} class="my-2">
          <div class="text-bold"><%= get_in(@fetched, [key, "title"]) %></div>
          <div class="inline text-slate-400 text-xs overflow-hidden"><%= get_in(@fetched, [key, "url"]) %></div>
        </div>
      </div>

    </div>
    """
  end

  defp fetch(key) do
    with {:ok, %{body: body}} <- Req.get("https://fly.storage.tigris.dev/nerves-fleet-data/#{key}", max_retries: 0) do
      {:ok, Jason.decode!(body)}
    end
  end

  defp fetch_latest_podcasts do
    Req.get!("https://fly.storage.tigris.dev/nerves-fleet-data/",
      params: %{
        "list-type" => 2,
        "prefix" => "shared/podcasts",
        "max-keys" => 12
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

  def find_transcripts(continuation_token \\ nil) do
    params =
      if continuation_token do
        %{"continuation-token" => continuation_token}
      else
        %{}
      end
      |> Map.merge(%{
        "list-type" => 2,
        "prefix" => "shared/podcasts",
      })

    body =
      Req.get!("https://fly.storage.tigris.dev/nerves-fleet-data/",
        params: params,
        headers: %{
          "X-Tigris-Query" => "`Content-Length` > 0 ORDER BY \`Last-Modified\` DESC"
        },
        max_retries: 0
      )
      |> Map.fetch!(:body)

    keys =
      body
      |> SweetXml.xpath(~x"//ListBucketResult/Contents/Key/text()"l)
      |> Enum.map(&to_string/1)

    continuation_token =
      body
      |> SweetXml.xpath(~x"//ListBucketResult/NextContinuationToken/text()")
      |> to_string()
      |> dbg()

    tkeys =
      keys
      |> Enum.filter(& String.contains?(&1, "transcript"))

    if keys == [] do
      tkeys
    else
      List.flatten([tkeys, find_transcripts(continuation_token)])
    end
  end
end
