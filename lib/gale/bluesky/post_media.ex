defmodule Gale.PostMedia do
  @base_url "https://cdn.bsky.app/img"

  def extract_images(post) do
    did = post["did"]

    case get_in(post, ["commit", "record", "embed", "images"]) do
      nil -> []
      images -> Enum.map(images, &parse_image(&1, did))
    end
  end

  defp parse_image(image, did) do
    %{
      alt: image["alt"],
      url: build_image_url(did, image["image"]["ref"]["$link"], image["image"]["mimeType"]),
      mime_type: image["image"]["mimeType"],
      aspect_ratio: parse_aspect_ratio(image["aspectRatio"])
    }
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
