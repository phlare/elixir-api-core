defmodule ElixirApiCore.Auth.Password do
  @spec hash_password(binary()) :: binary()
  def hash_password(password) when is_binary(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  @spec verify_password(binary(), binary()) :: boolean()
  def verify_password(password, password_hash)
      when is_binary(password) and is_binary(password_hash) do
    Bcrypt.verify_pass(password, password_hash)
  end

  def verify_password(_password, _password_hash) do
    Bcrypt.no_user_verify()
    false
  end
end
