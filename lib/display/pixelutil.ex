defmodule Inky.PixelUtil do
  @moduledoc """
  PixelUtil maps pixels to bitstrings to be sent to an Inky screen
  """

  def pixels_to_bits(pixels, width, height, rotation_degrees, color_map) do
    {outer_axis, dimension_vectors} =
      rotation_degrees
      |> normalised_rotation()
      |> rotation_opts()

    dimension_vectors
    |> rotated_ranges(width, height)
    |> do_pixels_to_bits(
      &pixels[pixel_key(outer_axis, &1, &2)],
      &(color_map[&1] || color_map.miss)
    )
  end

  @doc """
  Only exposed for testing purposes. Do not use.

      iex> Enum.map(
      ...>     [-360, -270, -180, -90, 0, 90, 180, 270, 360, 450],
      ...>     &Inky.PixelUtil.normalised_rotation/1
      ...> )
      [0, 1, 2, 3, 0, 1, 2, 3, 0, 1]
  """
  def normalised_rotation(degrees) do
    r = degrees |> div(90) |> rem(4)
    if(r < 0, do: r + 4, else: r)
  end

  @doc """
  Only exposed for testing purposes. Do not use.

      iex> Enum.map([3, 1, 2, 0], &Inky.PixelUtil.rotation_opts/1)
      [{:x, {{:x, -1}, {:y, 1}}},
       {:x, {{:x, 1}, {:y, -1}}},
       {:y, {{:y, -1}, {:x, -1}}},
       {:y, {{:y, 1}, {:x, 1}}}]
  """
  def rotation_opts(rotation) do
    case rotation do
      3 -> {:x, {{:x, -1}, {:y, 1}}}
      1 -> {:x, {{:x, 1}, {:y, -1}}}
      2 -> {:y, {{:y, -1}, {:x, -1}}}
      0 -> {:y, {{:y, 1}, {:x, 1}}}
    end
  end

  defp rotated_ranges({i_spec, j_spec}, i_n, j_m) do
    {
      rotated_dimension(i_n, j_m, i_spec),
      rotated_dimension(i_n, j_m, j_spec)
    }
  end

  defp rotated_dimension(width, _height, {:x, 1}), do: 0..(width - 1)
  defp rotated_dimension(width, _height, {:x, -1}), do: (width - 1)..0//-1
  defp rotated_dimension(_width, height, {:y, 1}), do: 0..(height - 1)
  defp rotated_dimension(_width, height, {:y, -1}), do: (height - 1)..0//-1

  defp do_pixels_to_bits({i_range, j_range}, pixel_picker, cmap) do
    for i <- i_range,
        j <- j_range,
        do: <<cmap.(pixel_picker.(i, j))::size(1)>>,
        into: <<>>
  end

  defp pixel_key(:x, i, j), do: {i, j}
  defp pixel_key(:y, i, j), do: {j, i}

  @doc """
  Converts pixels to a 4-bits-per-pixel binary for the UC8159 ACeP 7-color driver.
  Two pixels are packed per byte (high nibble = first pixel, low nibble = second pixel),
  traversed row by row, left to right. Width must be even.

  color_map must include a `:miss` key used as the default for unknown pixels.
  """
  def pixels_to_4bpp(pixels, width, height, color_map) do
    for y <- 0..(height - 1),
        x <- 0..(width - 1)//2,
        do: pack_nibble_pair(pixels, x, y, color_map),
        into: <<>>
  end

  defp pack_nibble_pair(pixels, x, y, color_map) do
    hi = color_map[pixels[{x, y}]] || color_map.miss
    lo = color_map[pixels[{x + 1, y}]] || color_map.miss
    <<hi::4, lo::4>>
  end
end
