export const getPrimaryManifestName = (name) => {
    const primaryName = [name].flat()[0];
    return typeof primaryName === "string" ? primaryName : "";
}

export const getTrimmedPrimaryManifestName = (name) => getPrimaryManifestName(name).trim();

export const isManifestNameUpdateValid = (nameError, currentName, originalName) => (
    nameError === "" &&
    getPrimaryManifestName(currentName) !== "" &&
    getTrimmedPrimaryManifestName(originalName) !== getTrimmedPrimaryManifestName(currentName)
);
