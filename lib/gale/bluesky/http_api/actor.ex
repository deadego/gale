defmodule Gale.Bluesky.HttpApi.Actor do
  @actor_url "https://public.api.bsky.app/xrpc/app.bsky.actor"

  def get_profile(actor) do
    case Req.get(@actor_url <> ".getProfile",
           params: [
             actor: actor
           ]
         ) do
      {:ok, %{status: 200, body: response}} ->
        response |> dbg()

      response ->
        response
    end
  end

  def get_profiles(actors) do
    case Req.get(@actor_url <> ".getProfiles",
           params: [
             actors: Enum.join(actors, ",")
           ]
         ) do
      {:ok, %{status: 200, body: response}} ->
        response

      response ->
        response
    end
  end
end
