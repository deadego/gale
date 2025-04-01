defmodule Gale.Bluesky.Auth do
  @create_session_url "https://bsky.social/xrpc/com.atproto.server.createSession"

  # Handle refresh tokens. @refresh_session_url "https://bsky.social/xrpc/com.atproto.server.refreshSession"

  def create_auth_token() do
    create_auth_token(
      Gale.config([:bluesky, :user]),
      Gale.config([:bluesky, :pass])
    )
  end

  def create_auth_token(user, pass) do
    case Req.post(@create_session_url,
           json: %{
             "identifier" => user,
             "password" => pass
           }
         ) do
      {:ok, %{status: 200, body: response}} ->
        response

      response ->
        response
    end
  end
end
