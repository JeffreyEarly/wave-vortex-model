function terms = evaluateManuscriptNonlinearTerms(varargin)
% Use the production Appendix C transcription in authoring studies.
% Independent Cartesian-equation and quadrature oracles live in the tests.
terms = WVInternal.freeSurfaceNonlinearTerms(varargin{:});
end
