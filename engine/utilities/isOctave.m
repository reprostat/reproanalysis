function resp = isOctave ()
  persistent testOctave;
  if (isempty (testOctave))
    testOctave = logical(exist ('OCTAVE_VERSION', 'builtin'));
  end
  resp = testOctave;
end
