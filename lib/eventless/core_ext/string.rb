class String
  def byteslice(*args)
    old_enc = encoding

    force_encoding('BINARY')
    ret = slice(*args)
    force_encoding(old_enc)

    ret.force_encoding(old_enc)

    ret
  end
end unless String.instance_methods.include? :byteslice
