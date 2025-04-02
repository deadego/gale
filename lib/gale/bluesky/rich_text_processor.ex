defmodule Gale.Bluesky.RichTextProcessor do
  def process(nil, _), do: ""

  def process(text, facets) do
    # Sort facets by byteStart and convert positions to integers
    prepared_facets =
      facets
      |> Enum.map(fn %{"index" => index, "features" => features} ->
        %{
          start: index["byteStart"],
          end: index["byteEnd"],
          features: features
        }
      end)
      |> Enum.sort_by(& &1.start)

    # Split text into segments
    {segments, last_pos} =
      Enum.reduce(prepared_facets, {[], 0}, fn facet, {acc, prev_end} ->
        # Get plain text before the facet
        plain_before = :binary.part(text, prev_end, facet.start - prev_end)

        # Get facet text
        facet_text = :binary.part(text, facet.start, facet.end - facet.start)

        # Generate link from facet metadata
        linked_text = generate_link(facet_text, facet.features)

        # Update accumulator and last position
        {[plain_before, linked_text | acc], facet.end}
      end)

    # Add remaining text after last facet
    remaining = :binary.part(text, last_pos, byte_size(text) - last_pos)
    segments = [remaining | segments]

    # Combine all parts in correct order
    Enum.reverse(segments)
    |> IO.iodata_to_binary()
  end

  defp generate_link(text, [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => tag}]) do
    ~s(<a class="text-brand" href="https://bsky.app/hashtag/#{tag}">#{text}</a> )
  end

  defp generate_link(text, [%{"$type" => "app.bsky.richtext.facet#mention", "did" => did}]) do
    ~s(<a class="text-brand" href="/profile/#{did}">#{text}</a> )
  end

  defp generate_link(text, [%{"$type" => "app.bsky.richtext.facet#link", "uri" => uri}]) do
    ~s(<a class="text-brand" href="#{uri}">#{text}</a> )
  end

  defp generate_link(text, _), do: text
end
