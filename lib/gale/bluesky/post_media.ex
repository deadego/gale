defmodule Gale.PostMedia do
  @base_url "https://cdn.bsky.app/img"

  def extract_video(post) do
    did = post["did"]

    case get_in(post, ["commit", "record", "embed", "video"]) do
      nil -> []
      video -> [parse_video(video, did)]
    end
  end

  def extract_external(post) do
    did = post["did"]
    uri = get_in(post, ["commit", "record", "embed", "external", "uri"]) || ""
    url_pattern = ~r/https?:\/\/[^\s]+\?hh=\d+&ww=\d+$/

    if Regex.match?(url_pattern, uri) do
      [
        %{
          uri: uri,
          thumb: %{
            url: uri
          }
        }
      ]
    else
      case get_in(post, ["commit", "record", "embed", "external"]) do
        nil -> []
        external -> [parse_external(external, did)]
      end
    end
  end

  def extract_images(post) do
    did = post["did"]

    case get_in(post, ["commit", "record", "embed", "images"]) do
      nil -> []
      images -> Enum.map(images, &parse_image(&1, did))
    end
  end

  defp parse_video(video, did) do
    %{
      url: build_video_url(did, video["ref"]["$link"])
    }
  end

  defp parse_external(external, did) do
    %{
      title: Map.get(external, "title"),
      uri: Map.get(external, "uri"),
      description: Map.get(external, "description"),
      thumb: %{
        url:
          build_image_url(did, external["thumb"]["ref"]["$link"], external["thumb"]["mimeType"]),
        mime_type: external["thumb"]["mimeType"]
      }
    }
  end

  defp parse_image(image, did) do
    %{
      alt: image["alt"],
      url: build_image_url(did, image["image"]["ref"]["$link"], image["image"]["mimeType"]),
      mime_type: image["image"]["mimeType"],
      aspect_ratio: parse_aspect_ratio(image["aspectRatio"])
    }
  end

  defp build_video_url(did, cid) do
    "https://bsky.social/xrpc/com.atproto.sync.getBlob?did=#{did}&cid=#{cid}"
  end

  defp build_image_url(did, cid, mime_type) do
    format = determine_format(mime_type)
    "#{@base_url}/feed_thumbnail/plain/#{did}/#{cid}@#{format}"
  end

  defp determine_format("image/png"), do: "png"
  defp determine_format("image/gif"), do: "gif"
  defp determine_format(_), do: "jpeg"

  defp parse_aspect_ratio(nil), do: nil
  defp parse_aspect_ratio(ratio), do: {ratio["width"], ratio["height"]}
end
