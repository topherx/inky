defmodule Inky.HAL.UC8159 do
  @default_io_mod Inky.RpiIO

  @moduledoc """
  An `Inky.HAL` implementation for the Inky Impression 7.3" display using the
  UC8159 ACeP 7-color eInk driver. Delegates to whatever IO module its user
  provides at init, but defaults to #{inspect(@default_io_mod)}.

  The UC8159 supports 7 colors: black, white, green, blue, red, yellow, orange.
  Note that the busy pin polarity is inverted relative to other Inky displays:
  HIGH (1) means ready, LOW (0) means busy.
  """

  @behaviour Inky.HAL

  import Bitwise

  alias Inky.PixelUtil

  @spi_speed_hz 3_000_000

  # UC8159 command registers
  @cmd_psr  0x00
  @cmd_pwr  0x01
  @cmd_pof  0x02
  @cmd_pfs  0x03
  @cmd_pon  0x04
  @cmd_btst 0x06
  @cmd_dtm1 0x10
  @cmd_drf  0x12
  @cmd_tse  0x41
  @cmd_cdi  0x50
  @cmd_tres 0x61
  @cmd_lpd  0x65
  @cmd_pws  0xE3

  @width  800
  @height 480

  @color_map %{black: 0, white: 1, green: 2, blue: 3, red: 4, yellow: 5, orange: 6, miss: 1}

  defmodule State do
    @moduledoc false

    @enforce_keys [:display, :io_mod, :io_state]
    defstruct [:display, :io_mod, :io_state]

    @type t :: %__MODULE__{}
  end

  #
  # API
  #

  @impl Inky.HAL
  def init(args) do
    display = args[:display] || raise(ArgumentError, message: ":display missing in args")
    io_mod = args[:io_mod] || @default_io_mod

    io_args = args[:io_args] || []
    io_args = if :gpio_mod in io_args, do: io_args, else: [gpio_mod: Circuits.GPIO] ++ io_args
    io_args = if :spi_mod in io_args, do: io_args, else: [spi_mod: Circuits.SPI] ++ io_args
    io_args = if :spi_speed_hz in io_args, do: io_args, else: [spi_speed_hz: @spi_speed_hz] ++ io_args

    %State{
      display: display,
      io_mod: io_mod,
      io_state: io_mod.init(io_args)
    }
  end

  @impl Inky.HAL
  def handle_update(pixels, _border, push_policy, state = %State{}) do
    pixel_data = PixelUtil.pixels_to_4bpp(pixels, @width, @height, @color_map)

    reset(state)

    case pre_update(state, push_policy) do
      :cont -> do_update(state, pixel_data)
      :halt -> {:error, :device_busy}
    end
  end

  #
  # Procedures
  #

  defp pre_update(state, :await) do
    await_device(state)
    :cont
  end

  # UC8159 busy polarity: 1 = ready, 0 = busy (inverted vs other Inky displays)
  defp pre_update(state, :once) do
    case read_busy(state) do
      1 -> :cont
      0 -> :halt
    end
  end

  defp do_update(state, pixel_data) do
    state
    |> write_command(@cmd_psr, [0xEF, 0x08])
    |> write_command(@cmd_pwr, [0x37, 0x00, 0x23, 0x23, 0x23])
    |> write_command(@cmd_pfs, [0x00])
    |> write_command(@cmd_btst, [0x3F, 0x3F, 0x11, 0x24])
    |> write_command(@cmd_tse, [0x00])
    |> write_command(@cmd_cdi, [0x37])
    |> write_command(@cmd_lpd, [0x00])
    |> write_command(@cmd_tres, [
      @width >>> 8, @width &&& 0xFF,
      @height >>> 8, @height &&& 0xFF
    ])
    |> write_command(@cmd_pws, [0xAA])
    |> write_command(@cmd_dtm1, pixel_data)
    |> write_command(@cmd_pon)
    |> await_device()
    |> write_command(@cmd_drf, [0x00])
    |> await_device()
    |> write_command(@cmd_pof)
    |> await_device()

    :ok
  end

  defp reset(state) do
    state
    |> set_reset(0)
    |> sleep(100)
    |> set_reset(1)
    |> sleep(100)
  end

  # UC8159: busy pin HIGH (1) = ready, LOW (0) = still busy
  defp await_device(state) do
    case read_busy(state) do
      0 -> state |> sleep(10) |> await_device()
      1 -> state
    end
  end

  #
  # Pipe-able wrappers
  #

  defp sleep(state, sleep_time) do
    io_call(state, :handle_sleep, [sleep_time])
    state
  end

  defp set_reset(state, value) do
    io_call(state, :handle_reset, [value])
    state
  end

  defp read_busy(state), do: io_call(state, :handle_read_busy)

  defp write_command(state, command) do
    io_call(state, :handle_command, [command])
    state
  end

  defp write_command(state, command, data) do
    io_call(state, :handle_command, [command, data])
    state
  end

  defp io_call(state, op, args \\ []) do
    apply(state.io_mod, op, [state.io_state | args])
  end
end
