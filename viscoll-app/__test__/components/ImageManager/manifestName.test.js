import {
    getPrimaryManifestName,
    getTrimmedPrimaryManifestName,
    isManifestNameUpdateValid,
} from '../../../src/components/imageManager/manifestName';

describe('manifestName helpers', () => {
    it('returns string manifest names unchanged', () => {
        expect(getPrimaryManifestName('Single label')).toEqual('Single label');
    });

    it('returns the first label from an array of manifest labels', () => {
        expect(getPrimaryManifestName(['First label', 'Second label'])).toEqual('First label');
    });

    it('trims the first label before comparing or submitting manifest names', () => {
        expect(getTrimmedPrimaryManifestName(['  First label  ', 'Second label'])).toEqual('First label');
    });

    it('falls back to an empty string for missing or non-string names', () => {
        expect(getPrimaryManifestName()).toEqual('');
        expect(getPrimaryManifestName([{value: 'First label'}])).toEqual('');
    });

    it('does not allow submit when the first label is unchanged', () => {
        expect(isManifestNameUpdateValid('', ['First label', 'Second label'], ['First label', 'Second label'])).toEqual(false);
    });

    it('allows submit when the first label changes', () => {
        expect(isManifestNameUpdateValid('', 'Updated label', ['First label', 'Second label'])).toEqual(true);
    });

    it('does not allow submit with a validation error or an empty first label', () => {
        expect(isManifestNameUpdateValid('Manifest name already exists.', 'Updated label', 'First label')).toEqual(false);
        expect(isManifestNameUpdateValid('', ['', 'Second label'], 'First label')).toEqual(false);
    });
});
