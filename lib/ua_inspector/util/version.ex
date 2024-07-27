defmodule UAInspector.Util.Version do
  @moduledoc false

  @doc """
  Compare two versions.

  ## Examples

      iex> compare("1.0.0", "1.0.1")
      :lt

      iex> compare("1.0.0", "1.0.0.4")
      :lt

      iex> compare("1.0.0.0", "1.0.0.1")
      :lt

      iex> compare("1.2.3", "1.02.03")
      :eq

      iex> compare("1.2.3", "1.020.3")
      :lt
  """
  @spec compare(binary, binary) :: :eq | :gt | :lt
  def compare(version1, version2) do
    semver1 = to_semver_with_pre(version1)
    semver2 = to_semver_with_pre(version2)

    Version.compare(semver1, semver2)
  end

  @doc """
  Extract the major version from a version string.

  ## Examples

      iex> major("1.0.0")
      1

      iex> major("5.2")
      5

      iex> major("invalid")
      0

      iex> major("-1.2.3")
      0
  """
  @spec major(binary) :: non_neg_integer
  def major(version) do
    semver = to_semver(version)

    case Version.parse(semver) do
      {:ok, %Version{major: major}} -> major
      _ -> 0
    end
  end

  @doc """
  Sanitizes a version string.
  """
  @spec sanitize(version :: String.t()) :: String.t()
  def sanitize(""), do: ""

  def sanitize(version) do
    version
    |> String.replace(~r/\$(\d)/, "")
    |> String.replace(~r/\.$/, "")
    |> String.replace("_", ".")
    |> String.trim()
  end

  @doc """
  Converts an unknown version string to a semver-comparable format.

  Missing values are filled with zeroes while empty strings are ignored.

  If a non-integer value is found it is ignored and every part
  including and after it will be a zero.

  ## Examples

      iex> to_semver("15")
      "15.0.0"

      iex> to_semver("3.6")
      "3.6.0"

      iex> to_semver("8.8.8")
      "8.8.8"

      iex> to_semver("")
      ""

      iex> to_semver("invalid")
      "0.0.0"

      iex> to_semver("3.help")
      "3.0.0"

      iex> to_semver("0.1.invalid")
      "0.1.0"

      iex> to_semver("1.2.3.4")
      "1.2.3"

      iex> to_semver("1.2.3.4", 4)
      "1.2.3-4"

      iex> to_semver("-1.2.3.4")
      "0.0.0"

      iex> to_semver("1.-2.3.4")
      "1.0.0"

      iex> to_semver("1.2.-3.4")
      "1.2.0"

      iex> to_semver("1.2.3.-4")
      "1.2.3"

      iex> to_semver("1.2.3-04")
      "1.2.3"

      iex> to_semver("1.2.3-04", 4)
      "1.2.3-4"

      iex> to_semver("1.2.3-004", 4)
      "1.2.3-4"

      iex> to_semver("1.2.3-000", 4)
      "1.2.3-0"

      iex> to_semver("1.2.3.04")
      "1.2.3"

      iex> to_semver("1.2.3.04", 4)
      "1.2.3-4"

      iex> to_semver("1.2.3.004", 4)
      "1.2.3-4"

      iex> to_semver("1.2.3.4-05", 4)
      "1.2.3-4-05"

      iex> to_semver("1.2.3.0")
      "1.2.3"

      iex> to_semver("1.2.3.0", 4)
      "1.2.3-0"

      iex> to_semver("1.2.3-0")
      "1.2.3"

      iex> to_semver("1.2.3-0", 4)
      "1.2.3-0"

      iex> to_semver("110.0.0.0.0")
      "110.0.0"

      iex> to_semver("110.0.0.0.0", 4)
      "110.0.0-0.0"
  """
  @spec to_semver(version :: String.t(), parts :: integer) :: String.t()
  def to_semver(version, parts \\ 3)
  def to_semver("", _), do: ""

  def to_semver(version, parts) do
    case String.split(version, ".", parts: parts) do
      [maj] -> to_semver_string(maj, "0", "0", nil)
      [maj, min] -> to_semver_string(maj, min, "0", nil)
      [maj, min, patch] -> to_semver_string(maj, min, patch, nil, parts == 4)
      [maj, min, patch, pre] -> to_semver_string(maj, min, patch, pre, parts == 4)
    end
  end

  defp to_semver_string(major, minor, patch, pre, add_pre? \\ false) do
    version =
      case {Integer.parse(major), Integer.parse(minor), Integer.parse(patch)} do
        {:error, _, _} -> "0.0.0"
        {{maj, _}, _, _} when maj < 0 -> "0.0.0"
        {{maj, _}, :error, _} -> "#{maj}.0.0"
        {{maj, _}, {min, _}, _} when min < 0 -> "#{maj}.0.0"
        {{maj, _}, {min, _}, :error} -> "#{maj}.#{min}.0"
        {{maj, _}, {min, _}, {patch, _}} when patch < 0 -> "#{maj}.#{min}.0"
        {{maj, _}, {min, _}, {patch, _}} -> "#{maj}.#{min}.#{patch}"
      end

    if pre = add_pre? && build_pre(patch, pre) do
      version <> "-" <> pre
    else
      version
    end
  end

  defp build_pre(patch, nil) do
    case String.split(patch, "-", parts: 2) do
      [_, pre] -> sanitize_pre(pre)
      _ -> nil
    end
  end

  defp build_pre(patch, dot_pre) do
    if pre = build_pre(patch, nil) do
      pre <> "." <> dot_pre
    else
      sanitize_pre(dot_pre)
    end
  end

  defp sanitize_pre(nil) do
    nil
  end

  defp sanitize_pre(pre) do
    pre
    |> String.split(".")
    |> Enum.map(&sanitize_pre_part/1)
    |> Enum.join(".")
  end

  defp sanitize_pre_part(str) do
    case Integer.parse(str) do
      {num, ""} -> to_string(num)
      _ -> str
    end
  end

  defp to_semver_with_pre(version) do
    semver = to_semver(version, 4)

    if String.contains?(semver, "-") do
      semver
    else
      semver <> "-0"
    end
  end
end
